# Passover Refactoring & Architecture Plan

This document outlines a clean, low-boilerplate mental model and restructuring plan for both the Android and macOS sides of the Passover app. The goal is to enforce the **Single Responsibility Principle (SRP)**: every file should have a predictable job that can be described in one simple sentence.

## The Mental Model: The Layer Cake

Imagine both apps as a pipeline. Data should flow up and down these layers predictably. By enforcing this symmetry across both Kotlin and Swift, jumping between codebases will become much easier.

1.  **Transports (The Dumb Pipes):** They don't know what the data is. They just move bytes, broadcast mDNS, and find IPs.
2.  **Security (The Vault):** Does math. Encrypts, decrypts, signs. Doesn't know about networks or persistence.
3.  **Protocol (The Codec/Translator):** Converts Protobuf `Message` objects to encrypted raw bytes, and vice versa.
4.  **Orchestration (The Boss/Engine):** Manages the state machine, glues components together, handles retries.
5.  **App/Lifecycle (The Wrapper):** OS-specific integrations (Services, AppDelegates, Notifications, Clipboards).

---

## 1. Android Restructuring Plan

Currently, `ConnectionRepository` is acting as a God Object, and `MainService` is micro-managing reconnections. 

### Layer 1: Transports (Keep as is)
*   **`WebSocketClient.kt`:** "I connect to a URL and emit raw `ByteArray`."
*   **`DnsServiceManager.kt`:** "I scan the local network and return IP addresses."

### Layer 2: Security 
Split `KeystoreManager`. It currently does cryptography *and* manages DataStore preferences.
*   **`CryptoEngine.kt`:** A pure utility class that takes a key and data, and returns encrypted/decrypted data. It does the math.
*   **`DeviceIdentityStore.kt`:** Handles reading/writing the `deviceId`, `wrappedGroupKey`, etc., from Android `DataStore`.

### Layer 3: Protocol
*   **`MessageCodec.kt`:** Creates a class whose *only* job is translation, removing the nested `try/catch` decryption logic from the repository.
    ```kotlin
    class MessageCodec @Inject constructor(private val crypto: CryptoEngine, private val ws: WebSocketClient) {
        // Takes raw bytes, handles try/catch decryption, and emits clean Protobuf Messages
        val incomingMessages: Flow<Message> 
        // Takes a Protobuf Message, encrypts it, and sends it to WebSocket
        fun sendMessage(message: Message, key: SecretKey?) 
    }
    ```

### Layer 4: Orchestration
*   **`SyncOrchestrator.kt` (Rename from `ConnectionRepository`):** "I maintain a connection to a trusted peer."
    *   Move the `delay(5000)` reconnection loop out of `MainService` and into here. This class manages its own connection state and backoff retry logic.
    *   It listens to `MessageCodec.incomingMessages` and exposes domain-specific flows like `val clipboardEvents: Flow<ClipboardMessage>`.

### Layer 5: App / Lifecycle
*   **`MainService.kt`:** Make it incredibly dumb. It just bridges the Android OS to the Orchestrator.
    ```kotlin
    override fun onCreate() {
        startForeground(NOTIFICATION_ID, createNotification("Syncing"))
        syncOrchestrator.start() // 1. Tell orchestrator to work
        
        lifecycleScope.launch {    // 2. Connect incoming data to OS
            syncOrchestrator.clipboardEvents.collect { clipboardHandler.updateClipboard(it) }
        }
    }
    ```

---

## 2. macOS Restructuring Plan

Currently, `NetworkManager` is acting as a WebSocket server, an mDNS broadcaster, a Protobuf parser, an encryption engine, and a pairing delegate. `PairingManager` holds raw TCP connections.

### Layer 1: Transports 
Extract network logic from `NetworkManager`.
*   **`WebSocketServer.swift`:** "I broadcast an mDNS service, accept TCP connections, and emit raw `Data`." It shouldn't know what a 'Message' or 'ClipboardMessage' is.

### Layer 2: Security 
Split `KeyStore`. Currently, it mixes Keychain persistence with CryptoKit math.
*   **`KeyStore.swift`:** Keep this strictly for saving/loading from the Keychain.
*   **`CryptoEngine.swift`:** Create pure functions/extensions for the math: `computeSasCode`, `encrypt`, `decrypt`, `deriveSessionKey`.

### Layer 3: Protocol
Remove the nested `do-catch` blocks from the networking receive handlers.
*   **`MessageCodec.swift`:** "I convert raw network `Data` into Swift Protobuf `Message` objects, applying encryption if needed."
    ```swift
    struct MessageCodec {
        static func decode(data: Data, groupKey: SymmetricKey?) -> Message? { /* decrypt or raw parse */ }
        static func encode(message: Message, groupKey: SymmetricKey?) -> Data? { /* serialize and encrypt */ }
    }
    ```

### Layer 4: Orchestration
*   **`SyncEngine.swift` (The Boss):** "I glue the Network, the Codec, the Clipboard, and the Pairing UI together."
    *   This is the central coordinator. It owns the `WebSocketServer` and listens to it, passes data to the Codec, and routes the resulting `Message` to either the Clipboard or the Pairing logic.
    *   Because `SyncEngine` handles the network sending, `PairingManager` becomes a pure UI state machine (`@ObservableObject`) and drops its `NWConnection` dependency.

### Layer 5: App / Lifecycle
*   **`AppDelegate.swift`:** Just like Android's `MainService`, this becomes extremely dumb.
    ```swift
    class AppDelegate: NSObject, NSApplicationDelegate {
        let syncEngine = SyncEngine()
        
        func applicationDidFinishLaunching(_ notification: Notification) {
            syncEngine.start()
        }
        
        // Predictable sleep/wake without destroying/recreating managers
        @objc func willSleep() { syncEngine.pause() }
        @objc func didWake() { syncEngine.resume() }
    }
    ```

## Benefits of this Architecture
1. **Isolated Bugs:** If decryption fails, look in `MessageCodec` or `CryptoEngine`. If the socket drops, look in `WebSocketServer`.
2. **No Networking in the UI:** UI state managers (`PairingManager`) no longer hold raw network connections.
3. **Symmetry:** Both Kotlin and Swift codebases will share the exact same mental model, making context-switching between the platforms seamless.
