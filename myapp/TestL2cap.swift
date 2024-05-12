import Foundation
import CoreBluetooth

class NewBleClient:NSObject, CBCentralManagerDelegate{
    var centralManager: CBCentralManager!
    let serviceUUID:CBUUID
    let centralQueue: DispatchQueue
    var peripheralDelegate: BleClientPeripheralDelegate?
    
    var isScanning = false
    var timer: Timer? = nil
    var currentPeripheral:CBPeripheral? = nil
    var peripheralDevice:CBPeripheral? = nil
    
    
    
    override init() {
        self.serviceUUID = BLEUtils.serviceID1
        self.centralQueue = DispatchQueue(label: "BLE central queue")
        super.init()
        self.peripheralDelegate = BleClientPeripheralDelegate()
        centralManager = CBCentralManager(delegate:self, queue: centralQueue)
        _ = AccessKeyManager.shared.getCurrentKey()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        print("reconnection to peripheral isReconnecting: \(isReconnecting)")
        print("reconnection to peripheral timestamp: \(timestamp)")
        print("reconnection to peripheral didDisconnectPeripheral: \(peripheral.description)")
        
    }
    
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // In your application, you would address each possible value of central.state and central.authorization
        switch central.state {
        case .resetting:
            print("Connection with the system service was momentarily lost. Update imminent")
        case .unsupported:
            print("Platform does not support the Bluetooth Low Energy Central/Client role")
        case .unauthorized:
            switch central.authorization {
            case .restricted:
                print("Bluetooth is restricted on this device")
            case .denied:
                print("The application is not authorized to use the Bluetooth Low Energy role")
            default:
                print("Something went wrong. Cleaning up cbManager")
            }
        case .poweredOff:
            print("Bluetooth is currently powered off")
        case .poweredOn:
            print("Starting cbManager")
            let uuid = BLEViewModel.shared.savedidentifier
            if uuid==nil{
                startScan()
            }
            else{
                let peripheral_list = central.retrievePeripherals(withIdentifiers: [uuid!])
                
                for peripheral in peripheral_list {
                    print("peripheral from identifier: \(peripheral.debugDescription)")
                    if peripheral.state == CBPeripheralState.disconnected {
                        var connectOptions:[String:Any] = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
                        if #available(macOS 14.0, *) {
                            connectOptions.updateValue(true, forKey: CBConnectPeripheralOptionEnableAutoReconnect)
                        } else {
                            print("autoconnect not support for this macos version")
                            
                        }
                        print("can send: \(peripheral.canSendWriteWithoutResponse)")
                        central.connect(peripheral, options: connectOptions)
                        peripheralDevice = peripheral
                        break
                    }
                }
            }
        default:
            print("Cleaning up cbManager")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
        print("NewBle: Found device: \(peripheral.identifier), rssi:\(RSSI)")
        BLEViewModel.shared.updateScanResult(peripheral: peripheral, rssi: RSSI)
        if (name != nil){
            print(name!)
        }
//        print(peripheral.identifier.uuidString)
//        connect(toPeripheral: peripheral)

    }
    

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("NewBle: Central manager connected to peripheral: \(peripheral.identifier) | MTU with: \(peripheral.maximumWriteValueLength(for: .withResponse))")
        BLEViewModel.shared.updateCurrentDevice(device: peripheral)
        peripheral.delegate = peripheralDelegate
        peripheral.discoverServices([BLEUtils.serviceID1])
        BLEStateManager.shared.change(isConnected: true)
//        PacketManager.shared.sendPacket(packet: AccessKeyManager.shared.getKeyData(), forceWrite: true)


//        MediaRemoteHelper.getNowPlayingInfo()
//        MediaManager.shared.publishData(overrideData: true)
//        PacketManager.shared.sendInitPacket()
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("NewBle: Central manager failed to connect to peripheral: \(peripheral.identifier) due to: \(String(describing: error?.localizedDescription))")
        BLEStateManager.shared.change(isConnected: false)
    }
    
    

    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("peripheral disconnected: \(peripheral.description)")
        startScan()
    }
    
/* ----------- Helper functions ----------------*/
    func startScan(){
        print("NewBle: Start Scanning")
        BLEViewModel.shared.updateScanStatus(status: true)
        centralManager.scanForPeripherals(withServices: [BLEUtils.serviceID])

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false){t in
            self.stopScan()
            print("NewBle: Stopped scanning after 10 seconds, t: \(t)")
        }
    }
    
    func stopScan(){
        centralManager.stopScan()
        BLEViewModel.shared.updateScanStatus(status: true)
    }
    
    func connect(toPeripheral peripheral:CBPeripheral){
        print("NewBle: Connecting to peripheral: \(peripheral.identifier)")
        stopScan()
        centralManager.connect(peripheral)
        peripheralDevice = peripheral
        
    }
    func disconnectDevice(fromPeripheral peripheral:CBPeripheral){
        print("NewBle: Cancel connection to peripheral: \(peripheral.identifier)")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
}

class BleClientPeripheralDelegate:NSObject, CBPeripheralDelegate{
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        print("NewBle: Service discovered")
        let services:[CBService]? = peripheral.services
        services?.forEach{service in
            print(service.uuid)
            if(service.uuid == BLEUtils.serviceID1){
                peripheral.discoverCharacteristics([], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        print("NewBle: Characteristics found for service: \(service.uuid)")
        let characteristics:[CBCharacteristic]? = service.characteristics
        characteristics?.forEach{ch in
            print("NewBle: Characteristic uuid: \(ch.uuid)")
            if(ch.uuid==BLEUtils.characteristicID){
                BLEStateManager.shared.change(currentPeripheral: peripheral, characteristic: ch)
            }
            if (ch.uuid == BLEUtils.characteristicID2){
                peripheral.setNotifyValue(true, for: ch)
                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("NewBle: Write characteristic Success 🔼, read: \(String(describing: characteristic.value))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("NewBle: update characteristic Success 🔽")
        if(characteristic.value?.isEmpty == false){
            let data = String(decoding: characteristic.value!, as: UTF8.self)
            let startIdx = data.index(data.startIndex, offsetBy: 1)
            let subData = String(data[startIdx...])
            let packetManager = PacketManager.shared
            if(data.starts(with: "N")){
                print("notification")
                packetManager.readNotification(mesage: subData)
            }
            else if(data.starts(with: "R")){
                packetManager.readRemoteMessage(message: subData)
            }
            
            
            print("Zata: \(type(of: data)), \(subData)")

            BLEStateManager.shared.readCharacteristic = characteristic
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("did modify service")
        print("invalidated service: \(invalidatedServices.description)")
        print("peripheral state after modify service: \(peripheral.description)")
        BLEStateManager.shared.change(isConnected: false)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        print("RSSI value: \(RSSI.description)")
    }
    

}


