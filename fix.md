# Passover Architecture Review & Fixes

## macOS App Review

This is a remarkably clean, flat, and well-thought-out architecture. As a fellow lazy (read: highly efficient) developer, I deeply appreciate the lack of bloat. You didn't pull in a massive third-party library for websockets; you used `Network.framework`. You didn't pull in a heavy crypto library; you used `CryptoKit` natively. 

Your trick using `NSPasteboard.PasteboardType("com.local.passover")` to tag your own clipboard writes and avoid an infinite echo loop is beautifully simple. Using `payload.hashValue` for deduplication to avoid storing massive strings in memory is also a great, resource-conscious move (and since `hashValue` only needs to be stable per-session, Swift's seed randomization doesn't break it).

However, looking at this through the lens of edge cases, resource constraints, and predictable state, there are a few architectural risks and subtle bugs that will eventually bite the user. Here is the review, categorized by priority.

### 1. The "Will Definitely Crash" Bug: Thread Safety in `NetworkManager`
You have a classic concurrent mutation race condition waiting to happen.
*   **The Setup:** `NetworkManager` manages its connections on a background queue (`networkQueue`). `listener`, `handleNewConnection`, and `removeConnection` all mutate the `connections` array on this queue.
*   **The Bug:** `ClipboardManager` processes images asynchronously using `Task(priority: .userInitiated)`. When it finishes, it fires the `onClipboardUpdate` closure, which calls `NetworkManager.sendClipboardData(...)`. This ends up calling `send(data:)`, which iterates over the `connections` array from a Swift Concurrency thread. 
*   **The Result:** Reading `connections` on an arbitrary thread while `networkQueue` is appending/removing connections will throw a fatal `Swift runtime failure: concurrent mutation` and crash the app.
*   **The Lazy Fix:** Just force all outbound sending to hop onto your network queue so the array is only ever touched by one thread.
    ```swift
    // In NetworkManager.swift
    private func send(data: Data) {
        networkQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.connections.isEmpty else { return }
            // ... rest of the send logic
        }
    }
    ```

### 2. Beating up the Mac's Battery: The Polling Timer
macOS is very aggressive about putting the CPU to sleep (App Nap, power constraints). Your `ClipboardManager` uses a rigid 1-second `Timer`. Because it has no tolerance, macOS is forced to wake the app's runloop exactly every 1000ms, preventing the CPU from fully resting, which will show up in the Mac's Activity Monitor as high Energy Impact.
*   **The Lazy Fix:** Give the timer a `.tolerance`. This allows the OS to coalesce your timer with other system events. This one line will significantly drop the energy footprint without changing your logic.
    ```swift
    private func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        timer?.tolerance = 0.5 // Let the OS shift this by up to 500ms to save battery
    }
    ```
    *Note: You could also back-off the polling interval to 2-3 seconds if the user hasn't interacted with the Mac recently (using `CGEventSourceSecondsSinceLastEventType`), but the tolerance fix is the easiest immediate win.*

### 3. Edge Case: The "Double Confirm" Key Overwrite
In `PairingManager`, when `confirmSas()` is called, the Mac encrypts its `GroupKey` and sends it to Android. If Android's implementation is identical, Android will *also* encrypt its GroupKey and send it to the Mac. 
*   **The Edge Case:** If both users hit "Confirm" on their respective devices roughly around the same time, they both fire `HandshakeMessage`s. Mac receives Android's key and saves it. Android receives Mac's key and saves it. They have now effectively swapped keys, are completely out of sync, and all future payload decryption will fail.
*   **The Lazy Fix:** You need a deterministic way to decide whose `GroupKey` wins so they both end up using the same one. The easiest, zero-configuration way is to sort the device IDs.
    ```swift
    // In PairingManager.swift -> handleIncomingHandshake
    let peerDeviceId = peerIdentity.deviceID
    let myDeviceId = self.deviceId
    
    // Only accept their group key if their ID is lexicographically greater than ours.
    // Otherwise, we ignore it, knowing they will accept OUR key because ours is greater.
    if peerDeviceId > myDeviceId {
        let groupKeyBytes = try KeyStore.decrypt(Data(handshake.encryptedGroupKey), using: sessionKey)
        KeyStore.saveGroupKey(SymmetricKey(data: groupKeyBytes))
    }
    ```

### 4. Robustness: The Try-Decrypt-Everything Loop
In `NetworkManager.receive(on:)`, you aggressively attempt to AES-GCM decrypt *every* incoming payload if a `groupKey` exists. If decryption throws an error, you catch it and say: *"GroupKey decrypt failed, trying as pairing message"*.
*   **Why it's a bit dirty:** AES-GCM authentication failure is an expensive way to route network traffic. If a random device on the network probes that port with garbage data, the app will constantly run decryption failures, logging errors, and attempting to parse the garbage as a Protobuf pairing message.
*   **The Lazy Fix:** You don't have to redesign the protocol. But you *can* check the connection state. Only attempt plain Protobuf parsing if `PairingManager` is actively in a pairing state or if the device is not yet in the trusted peers list. Alternatively, wrap your websocket payloads in a simple 1-byte header: `[0x00, ...payload]` for plain pairing, `[0x01, ...payload]` for encrypted data. 

### 5. Lifecycle Cleanliness: Sleep/Wake Closures
In `AppDelegate`, you set the `networkManager.onClipboardMessage` and `clipboardManager.onClipboardUpdate` closures in `applicationDidFinishLaunching`. Then, in `willSleep`, you destroy the clipboard manager. In `didWake`, you recreate it, and *re-assign the closures*.
*   Since `NetworkManager` is a singleton, you are constantly overwriting its closure on wake. It works, but it's messy state management.
*   **The Lazy Fix:** Instead of destroying `ClipboardManager`, just tell it to pause. 
    ```swift
    // In ClipboardManager.swift
    func pause() { timer?.invalidate() }
    func resume() { startMonitoringClipboard() }
    
    // In AppDelegate.swift
    @objc func willSleep() {
        clipboardManager?.pause()
        networkManager.close()
    }
    @objc func didWake() {
        networkManager.start() // Handles its own internal listener/monitor rebuild
        clipboardManager?.resume()
    }
    ```
    This removes the need to constantly re-wire the closures and ensures your objects maintain predictable lifecycles.

---

## Android App Review

This Android counterpart is just as impressive as the macOS side. The architecture is incredibly modern—you've fully leaned into Kotlin Coroutines, `Flow` (`StateFlow`/`SharedFlow`), and Hilt for dependency injection, keeping the data layer decoupled from the UI. 

Using an `AccessibilityService` to listen for `TYPE_VIEW_CLICKED` on "Copy" buttons or `TYPE_NOTIFICATION_STATE_CHANGED` for clipboard toasts is a **brilliant, lazy-in-the-best-way workaround** for Android 10+'s draconian background clipboard restrictions. It saves you from having to build a custom keyboard or complex input method just to grab text.

However, moving from the permissive macOS environment to the highly constrained Android environment introduces some specific edge cases, primarily around battery life and system resource management. Here is the review:

### 1. The "Battery Destroyer": Aggressive NsdManager Polling
In `MainService`, you have a reconnection loop that fires when the connection state goes to `FAILED`.
*   **The Bug:** It waits 5 seconds (`delay(5000)`), then calls `connectToFirstTrustedPeer()`. This triggers `DnsServiceManager.findService()`, which runs a 15-second NsdManager discovery timeout. If the Mac is turned off, this fails. `MainService` sees the `FAILED` state, waits 5 seconds, and runs another 15-second discovery. 
*   **The Result:** While the Android screen is ON (you smartly pause it on screen OFF), the WiFi radio is actively doing mDNS discovery for 15 out of every 20 seconds. If a user uses their phone for an hour while their Mac is asleep, Passover will completely drain their battery.
*   **The Lazy Fix:** Implement a simple exponential backoff for the reconnection delay, capping it at a reasonable ceiling (like 5 minutes) so you aren't fighting the OS.
    ```kotlin
    // In MainService.kt
    private var reconnectAttempt = 0

    private fun scheduleReconnection() {
        if (isPaused || reconnectionJob?.isActive == true) return
        
        reconnectAttempt++
        // 5s, 10s, 20s, 40s... maxing out at 5 minutes (300,000ms)
        val delayTime = minOf(5000L * (1 shl (reconnectAttempt - 1)), 300_000L)
        
        reconnectionJob = lifecycleScope.launch {
            delay(delayTime)
            try {
                if (connectionRepo.hasTrustedPeers.first()) connectToFirstTrustedPeer()
            } catch (e: Exception) {}
        }
    }
    
    // Remember to reset `reconnectAttempt = 0` when ConnectionState goes to CONNECTED!
    ```

### 2. The "Gallery Spam" Bug: MediaStore Image Saving
In `ClipboardHandler.kt`, when an image is received from the Mac, you use `MediaStore` to save the decoded PNG directly into `Environment.DIRECTORY_PICTURES + "/ClipboardImages"`.
*   **The Edge Case:** `MediaStore` is the public photo gallery. Every single time the user copies an image on their Mac, it will permanently appear in their Android device's Google Photos or Gallery app. After a few weeks, their camera roll will be flooded with random screenshots and UI snippets.
*   **The Lazy Fix:** Stop using `MediaStore` for transient clipboard data. Save the image to the app's internal `cacheDir`. You'll need to use a `FileProvider` to generate a URI that other apps can read when they paste, but this keeps the images out of the user's personal photo album and lets Android clean up the files automatically when storage gets low.
    ```kotlin
    // In ClipboardHandler.kt (Conceptual)
    val cacheFile = File(context.cacheDir, "clipboard_image.png")
    cacheFile.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    // Then use FileProvider.getUriForFile(...) to get the URI for the ClipData
    ```

### 3. Race Condition: NsdManager Discovery Leak
In `DnsServiceManager.kt`, you wrap `nsdManager.discoverServices` inside a `suspendCancellableCoroutine`. You have an `invokeOnCancellation` block that calls `stopDiscoverySafe(discoveryListener)`.
*   **The Edge Case:** Coroutine cancellation can happen *extremely* fast. If the coroutine is cancelled *before* the `nsdManager.discoverServices(...)` call actually executes on the underlying OS thread, `invokeOnCancellation` will fire, attempt to unregister the listener (catching the `IllegalArgumentException` because it wasn't registered yet), and *then* the system will register the discovery listener. 
*   **The Result:** A zombie mDNS discovery process running indefinitely in the background, consuming memory and battery because your app lost the reference to the listener and can never stop it.
*   **The Lazy Fix:** Set a flag when registration actually starts, and verify it in your cancellation block.
    ```kotlin
    var isRegistered = false
    discoveryListener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(serviceType: String) {
            isRegistered = true
            // ...
        }
    }
    continuation.invokeOnCancellation {
        if (isRegistered) stopDiscoverySafe(discoveryListener)
    }
    nsdManager.discoverServices(...)
    ```

### 4. Structural Limitation: `firstOrNull()` Peer Connection
In `MainService.kt`, you connect using:
```kotlin
val peer = trustedPeerStore.getAllPeers().firstOrNull()
```
*   **The Edge Case:** If the user pairs a desktop Mac, and then later pairs a MacBook laptop, `TrustedPeerStore` will contain two devices. `MainService` will arbitrarily only ever attempt to connect to whichever device happens to be at index `0` of the array. If the user is sitting in a coffee shop with their MacBook, but their desktop Mac at home is index `0`, the app will endlessly try and fail to connect to the desktop and completely ignore the laptop sitting right next to it.
*   **The Lazy Fix:** Since mDNS `discoverServices()` (which you already wrote) can find *any* local Passover service, use that first! Instead of aggressively attempting to connect to a specific saved ID, run a background mDNS discovery. When it finds a Passover service, check if its `deviceId` exists in `trustedPeerStore`. If it does, *then* execute the WebSocket connection.
