import Foundation
import IOBluetooth
import os

class HFDState: ObservableObject{
    static let shared = HFDState()
    @Published var is_connected:Bool = false
    @Published var devicename:String = ""
    @Published var is_active: Bool = false
    @Published var callHoldState:Int = 0
    @Published var callSetupMode:Int = 0
    var battery: Int = 4
    @Published var signal:Int = 5
    @Published var isRoaming:Bool = false
    @Published var currentCall: [AnyHashable : Any] = [:]
    @Published var callMapping: [String : String] = [
        "number": "123456789",
        "mode": "in",
        "status": "ringing",
        "timer": "-:-"
    ]
    @Published var batteryText:String = "battery.100percent"
    @Published var elapsedTimeString: String = "00:00:00"
    var call_timer:SimpleTimer? = nil
    
    
    private init(){}
    
    func update(isConnected: Bool){
        DispatchQueue.main.async {
            self.is_connected = isConnected
        }
    }
    func update(elapsedTimeString: String){
        DispatchQueue.main.async {
            self.elapsedTimeString = elapsedTimeString
        }
    }

    func update(is_active: Bool){
        if is_active{
            self.call_timer = SimpleTimer.shared
            SimpleTimer.shared.resetTimer()
            WindowManager.shared.openCallAlert(windowName: .CallPopUP)
        }
        else{
            SimpleTimer.shared.stopTimer()
            self.call_timer = nil
            WindowManager.shared.closeCallAlert(windowName: .CallPopUP)
        }
        DispatchQueue.main.async {
            self.is_active = is_active
        }
    }
    func update(isRoaming: Bool){
        DispatchQueue.main.async {
            self.isRoaming = isRoaming
        }
    }
    func update(callHoldState: Int){
        if callHoldState == 1{
//            incoming call
        }
        DispatchQueue.main.async {
            self.callHoldState = callHoldState
        }
    }
    func update(callSetupMode: Int){
        switch callSetupMode{
        case 0:
            WindowManager.shared.closeCallAlert(windowName: .CallAlert)
            if !self.is_active{
                WindowManager.shared.closeCallAlert(windowName: .CallPopUP)
            }
        case 1:
            WindowManager.shared.openCallAlert(windowName: .CallAlert)
        case 2:
            WindowManager.shared.openCallAlert(windowName: .CallPopUP)
        case 3:
            WindowManager.shared.openCallAlert(windowName: .CallPopUP)
        default:
            WindowManager.shared.closeCallAlert(windowName: .CallAlert)
            
        }
        DispatchQueue.main.async {
            self.callSetupMode = callSetupMode
        }
    }
    func update(battery: Int){
        DispatchQueue.main.async {
            self.batteryText =  getBatteryString(charge: battery)
            self.battery = battery
        }
    }
    func update(signal: Int){
        let _signal = switch signal{
        case 0:
            0
        case 1:
            1
        case 2:
            2
        case 3:
            2
        case 4:
            3
        case 5:
            4
        default:
            4
        }
        DispatchQueue.main.async {
            self.signal = _signal
        }
    }
    func update(currentCall: [AnyHashable : Any]){
        if let number = currentCall["number"] as? String{
            self.callMapping["number"] = number
        }
        else{
            self.callMapping["number"] = "Unknown Number"
        }
        
        if let direction = currentCall["direction"] as? Int{
            if direction == 0{
                self.callMapping["mode"] = "out"
            }
            else{
                self.callMapping["mode"] = "in"
            }
        }
        else{
            self.callMapping["mode"] = "out"
        }
        if let status = currentCall["status"] as? Int{
            switch status{
            case 0:
                self.callMapping["status"] = "talking"
            case 1:
                self.callMapping["status"] = "on Hold"
            case 2:
                self.callMapping["status"] = "dialing"
            default:
                self.callMapping["status"] = "waiting"
            }
        }
        else{
            self.callMapping["status"] = "waiting"
        }
        if call_timer != nil{
            self.callMapping["timer"] = call_timer?.getElapsedTime()
        }
        else{
            self.callMapping["timer"] = "-:-"
        }
        DispatchQueue.main.async {
            self.currentCall = currentCall
        }
    }
}
