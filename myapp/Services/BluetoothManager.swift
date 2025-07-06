import AppKit
import CoreBluetooth
import IOBluetooth
import OSLog

// MARK: - Helper Structs and Enums

struct Peripheral: Identifiable, Equatable {
    let id: String // MAC Address
    let name: String
    let device: IOBluetoothDevice

    init(from device: IOBluetoothDevice) {
        self.id = device.addressString
        self.name = device.nameOrAddress ?? "Unknown Device"
        self.device = device
    }

    static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
        return lhs.id == rhs.id
    }
}

enum BluetoothConnectionState: Equatable {
    case idle
    case scanning
    case connecting(Peripheral)
    case connected(Peripheral)
    case powerOff
}

// MARK: - BluetoothManager

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    // MARK: - Published Properties for UI
    @Published var discoveredPeripherals: [Peripheral] = []
    @Published var state: BluetoothConnectionState = .idle
    @Published var stateInfo: String = "Initializing..."
    @Published var isBluetoothPoweredOn: Bool = false

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    private var inquiry: IOBluetoothDeviceInquiry?
    private let bluetoothQueue = DispatchQueue(label: "com.yourapp.bluetooth.queue", qos: .userInitiated)
    private let userDefaultsDeviceAddressKey = "savedBluetoothDeviceAddress"

    // MARK: - Lifecycle
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
        setupSleepWakeNotifications()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopScanning()
        disconnect()
    }

    // MARK: - Public API
    
    /// Starts scanning for nearby Bluetooth devices.
    func startScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self = self, self.centralManager.state == .poweredOn else { return }
            
            // Prevent starting a new scan if one is already in progress
            guard self.inquiry == nil else {
                Logger.connection.debug("Inquiry is already active.")
                return
            }
            
            Logger.connection.debug("Starting Scan...")
            DispatchQueue.main.async {
                self.discoveredPeripherals.removeAll()
                self.updateState(.scanning, info: "Scanning for devices...")
            }

            self.inquiry = IOBluetoothDeviceInquiry(delegate: self)
            self.inquiry?.updateNewDeviceNames = true
            self.inquiry?.start()
        }
    }
    
    /// Stops the ongoing device scan.
    func stopScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self = self, self.inquiry != nil else { return }
            self.inquiry?.stop()
            self.inquiry = nil
            Logger.connection.debug("Scan stopped.")
            if self.state == .scanning {
                self.updateState(.idle, info: "Scan stopped.")
            }
        }
    }

    /// Initiates a connection to a given peripheral.
    func connect(to peripheral: Peripheral) {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopScanning()
            self.updateState(.connecting(peripheral), info: "Connecting to \(peripheral.name)...")
            
            // The first step is ALWAYS to run an SDP query.
            self.runSDPQuery(for: peripheral.device)
        }
    }

    /// Disconnects from the currently connected peripheral.
    func disconnect() {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let channel = self.rfcommChannel, channel.isOpen() {
                channel.close()
                self.rfcommChannel = nil
            }
            
            if case .connected(let peripheral) = self.state {
                if peripheral.device.isConnected() {
                    peripheral.device.closeConnection()
                }
            }
            
            // Clear cached device if user explicitly disconnects
            self.clearSavedDeviceAddress()
            self.updateState(.idle, info: "Disconnected")
        }
    }
    
    /// Sends data to the connected peripheral.
    func send(data: Data) {
        bluetoothQueue.async { [weak self] in
            guard let self = self, let channel = self.rfcommChannel, channel.isOpen() else {
                Logger.connection.warning("Cannot send data. RFCOMM channel is not open.")
                return
            }

            var mutableData = data
            let result = mutableData.withUnsafeMutableBytes { rawBuffer in
                channel.writeSync(rawBuffer.baseAddress!, length: UInt16(data.count))
            }
            
            if result == kIOReturnSuccess {
                Logger.connection.debug("Successfully sent \(data.count) bytes.")
            } else {
                Logger.connection.error("Failed to send data. Error: \(result)")
            }
        }
    }
    
    // MARK: - Private Helper Methods

    /// Main entry point after Bluetooth is powered on.
    private func initiateConnectionProcess() {
        if let address = getSavedDeviceAddress(), let device = IOBluetoothDevice(addressString: address) {
            Logger.connection.info("Found saved device: \(device.nameOrAddress ?? address). Attempting to connect.")
            let peripheral = Peripheral(from: device)
            self.connect(to: peripheral)
        } else {
            Logger.connection.info("No saved device found. Starting scan.")
            self.startScanning()
        }
    }

    /// Runs an SDP query to find the RFCOMM channel for our target service.
    private func runSDPQuery(for device: IOBluetoothDevice) {
        updateStateInfo("Discovering services...")
        if device.performSDPQuery(self) != kIOReturnSuccess {
            Logger.connection.error("Failed to start SDP query for \(device.nameOrAddress ?? "device").")
            self.updateState(.idle, info: "Error: Could not start service discovery.")
        }
    }
    
    /// Called from the SDP query callback. Attempts to open the RFCOMM channel.
    private func connectToRfcommChannel(on device: IOBluetoothDevice) {
        guard let services = device.services as? [IOBluetoothSDPServiceRecord] else {
            updateState(.idle, info: "Error: Could not retrieve services.")
            return
        }

        var channelID: BluetoothRFCOMMChannelID = 0
        for service in services {
            // IMPORTANT: Replace "cBluetoothServer" with your actual service name
            if let name = service.getServiceName(), name == "cBluetoothServer" {
                service.getRFCOMMChannelID(&channelID)
                break
            }
        }

        guard channelID != 0 else {
            updateState(.idle, info: "Error: Service not found on this device.")
            return
        }
        
        updateStateInfo("Found service. Opening communication channel...")
        
        // This call is synchronous and will block the bluetoothQueue, which is fine.
        var channel: IOBluetoothRFCOMMChannel? = nil
        if device.openRFCOMMChannelSync(&channel, withChannelID: channelID, delegate: self) == kIOReturnSuccess {
             self.rfcommChannel = channel
             // The final state update happens in the `rfcommChannelOpenComplete` delegate method.
        } else {
            Logger.connection.error("RFCOMM connection failed for channel ID \(channelID).")
            self.updateState(.idle, info: "Error: Could not open communication channel.")
        }
    }

    private func updateState(_ newState: BluetoothConnectionState, info: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
            if let info = info {
                self?.stateInfo = info
            }
        }
    }
    
    private func updateStateInfo(_ info: String) {
        DispatchQueue.main.async { [weak self] in
            self?.stateInfo = info
        }
    }
    
    // MARK: - Persistence
    private func saveDeviceAddress(_ address: String) {
        UserDefaults.standard.set(address, forKey: userDefaultsDeviceAddressKey)
        Logger.connection.info("Saved device address: \(address)")
    }

    private func getSavedDeviceAddress() -> String? {
        return UserDefaults.standard.string(forKey: userDefaultsDeviceAddressKey)
    }
    
    private func clearSavedDeviceAddress() {
        UserDefaults.standard.removeObject(forKey: userDefaultsDeviceAddressKey)
        Logger.connection.info("Cleared saved device address.")
    }
    
    // MARK: - System Sleep/Wake Handling
    private func setupSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func systemWillSleep() {
        Logger.connection.info("System will sleep. Disconnecting.")
        self.disconnect()
    }

    @objc private func systemDidWake() {
        Logger.connection.info("System did wake. Re-initializing connection.")
        // Give Bluetooth services a moment to come back online.
        bluetoothQueue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.initiateConnectionProcess()
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isBluetoothPoweredOn = central.state == .poweredOn }
            
            switch central.state {
            case .poweredOn:
                self.updateState(.idle, info: "Bluetooth is On")
                self.initiateConnectionProcess()
            case .poweredOff:
                self.updateState(.powerOff, info: "Please turn on Bluetooth")
                DispatchQueue.main.async { self.discoveredPeripherals.removeAll() }
            default:
                self.updateState(.powerOff, info: "Bluetooth not available")
                DispatchQueue.main.async { self.discoveredPeripherals.removeAll() }
            }
        }
    }
}

// MARK: - IOBluetoothDeviceInquiryDelegate
extension BluetoothManager: IOBluetoothDeviceInquiryDelegate {
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        let newPeripheral = Peripheral(from: device)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.discoveredPeripherals.contains(newPeripheral) else { return }
            Logger.connection.debug("Found device: \(newPeripheral.name) (\(newPeripheral.id))")
            self.discoveredPeripherals.append(newPeripheral)
        }
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        Logger.connection.info("Inquiry complete. Aborted: \(aborted), Error: \(error)")
        if self.state == .scanning {
             self.updateState(.idle, info: "Scan finished.")
        }
    }
}

// MARK: - SDP Query Callback (on NSObject)
extension BluetoothManager {
    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard status == kIOReturnSuccess else {
                Logger.connection.error("SDP query failed for device \(device.nameOrAddress ?? ""). Status: \(status)")
                self.updateState(.idle, info: "Error: Could not find required services.")
                return
            }
            
            Logger.connection.debug("SDP query successful for \(device.nameOrAddress ?? "").")
            // Now that SDP is successful, we can proceed to open the RFCOMM channel.
            self.connectToRfcommChannel(on: device)
        }
    }
}


// MARK: - IOBluetoothRFCOMMChannelDelegate
extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            
            if error == kIOReturnSuccess {
                Logger.connection.info("✅ RFCOMM Channel Opened Successfully!")
                let peripheral = Peripheral(from: rfcommChannel.getDevice())
                self.updateState(.connected(peripheral), info: "Connected to \(peripheral.name)")
                // Cache the address upon successful connection
                self.saveDeviceAddress(peripheral.id)
            } else {
                Logger.connection.error("RFCOMM open failed. Error: \(error)")
                self.updateState(.idle, info: "Connection failed.")
            }
        }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.warning("RFCOMM channel closed.")
        // Only reset to idle if we were previously in a connected state
        if case .connected = self.state {
            self.updateState(.idle, info: "Disconnected")
        }
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        Logger.connection.debug("Received \(data.count) bytes.")
        // TODO: Handle your incoming data here.
        
    }
}
