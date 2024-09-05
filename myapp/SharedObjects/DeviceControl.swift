import Foundation

import CoreBluetooth
import IOBluetooth

class DeviceControl{
    static let shared = DeviceControl()
    
    var charge: Int = 5
    var signal:Int = 5
    var notificationCount = 6
    
    private init() {}
    
}
