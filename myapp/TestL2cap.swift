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
        MediaRemoteHelper.getNowPlayingInfo()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn{
            print("NewBle: central.state is .poweredOn")
            startScan()
            print("NewBle: scan!")
        }
        else{
            print("NewBle: central.state is .poweredOff")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("NewBle: Central manager connected to peripheral: \(peripheral.identifier)")
        print("MTU: \(peripheral.maximumWriteValueLength(for: .withResponse))")
        peripheral.delegate = peripheralDelegate
        peripheral.discoverServices([BLEUtils.serviceID1])
        BLEStateManager.shared.change(isConnected: true)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("NewBle: Central manager failed to connect to peripheral: \(peripheral.identifier) due to: \(String(describing: error?.localizedDescription))")
        BLEStateManager.shared.change(isConnected: false)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
        print("NewBle: Found device: \(peripheral.identifier)")
        if (name != nil){
            print(name!)
        }
        print(peripheral.identifier.uuidString)
        
        print("NewBle: trying to connect now!")
        connect(toPeripheral: peripheral)

        let id = UUID(uuidString: "E0B84E6D-A385-5C70-9BDF-D021297F9EDF")
        let list = central.retrieveConnectedPeripherals(withServices: [BLEUtils.serviceID1])
        let list1 = central.retrievePeripherals(withIdentifiers: [id!])
        print("Retreived peripherals \(list.description)")
        print("Retreived peripherals1 \(list1.description)")

/*
 NewBle: Found device: B2B36C02-AABF-9374-D5CB-84D567E7C866
 NewBle: Found device: 823D10ED-D53F-8EC6-AFAF-A394BED67426
 */
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("peripheral disconnected: \(peripheral.description)")
        startScan()
    }
    
/* ----------- Helper functions ----------------*/
    func startScan(){
        print("NewBle: Start Scanning")
        isScanning = true
        centralManager.scanForPeripherals(withServices: [BLEUtils.serviceID])

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false){t in
            self.stopScan()
            print("NewBle: Stopped scanning after 10 seconds, t: \(t)")
        }
    }
    
    func stopScan(){
        isScanning = false
        centralManager.stopScan()
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
                print("Sending message over ble")
            }
            if (ch.uuid == BLEUtils.characteristicID2){
//                peripheral.readValue(for: ch)
                peripheral.setNotifyValue(true, for: ch)
                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("NewBle: Write characteristic Success 🔼")
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("NewBle: update characteristic Success 🔽")
        if(characteristic.value?.isEmpty == false){
            let data = String(decoding: characteristic.value!, as: UTF8.self)
            let startIdx = data.index(data.startIndex, offsetBy: 1)
            let subData = String(data[startIdx...])
            let packetManager = PacketManager.shared
            if(data.starts(with: "N")){
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


