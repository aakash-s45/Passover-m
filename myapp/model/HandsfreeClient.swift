//
//  HandsfreeClient.swift
//  myapp
//
//  Created by Aakash Solanki on 07/07/24.
//

import Foundation
import IOBluetooth
import OSLog
import UserNotifications

class HFDeviceDelegate:NSObject, IOBluetoothHandsFreeDeviceDelegate, IOBluetoothHandsFreeAudioGatewayDelegate{
    func handsFree(_ device: IOBluetoothHandsFree!, connected status: NSNumber!) {
        Logger.connection.debug("Connection status HF Device: \(status)")
        Logger.connection.debug("device sco connected \(device.isSCOConnected())")
    }
    
    func handsFree(_ device: IOBluetoothHandsFree!, disconnected status: NSNumber!) {
        Logger.connection.debug("Disconnection status HF Device: \(status)")
        HFDState.shared.update(handFreeDevice: nil)
    }
    
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, isRoaming: NSNumber!) {
        Logger.connection.debug("is Roaming HF Device: \(isRoaming)")
        if isRoaming == 1{
            HFDState.shared.update(isRoaming: true)
        }
        else{
            HFDState.shared.update(isRoaming: false)
        }
        
    }
    
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, currentCall: [AnyHashable : Any]!) {
        print("Current call: \(currentCall.debugDescription)")
        HFDState.shared.update(currentCall: currentCall)
//        Logger.connection.debug("current call HF Device: \(currentCall.debugDescription)")
    }
    
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, incomingSMS sms: [AnyHashable : Any]!) {
        Logger.connection.debug("incomingSMS HF Device: \(sms.description)")
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, ringAttempt: NSNumber!) {
        Logger.connection.debug("ringAttempt HF Device: \(ringAttempt)")
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, batteryCharge: NSNumber!) {
        Logger.connection.debug("batteryCharge HF Device: \(batteryCharge)")
        HFDState.shared.update(battery: batteryCharge as! Int)
        HFDState.shared.update(handFreeDevice: device)
        
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, signalStrength: NSNumber!) {
        Logger.connection.debug("signalStrength HF Device: \(signalStrength)")
        HFDState.shared.update(signal: signalStrength as! Int)
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, isCallActive: NSNumber!) {
        if isCallActive == 1{
            HFDState.shared.update(is_active: true)
        }
        else{
            HFDState.shared.update(is_active: false)
        }
        Logger.connection.debug("isCallActive HF Device: \(isCallActive)")
    
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, callHoldState: NSNumber!) {
        Logger.connection.debug("callHoldState HF Device: \(callHoldState)")
        HFDState.shared.update(callHoldState: callHoldState as! Int)
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, callSetupMode: NSNumber!) {
        Logger.connection.debug("callSetupMode HF Device: \(callSetupMode)")
        device.currentCallList()
        if callSetupMode == 1{
            device.subscriberNumber()
        }
        HFDState.shared.update(callSetupMode: callSetupMode as! Int)
    }
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, incomingCallFrom number: String!) {
        print("incoming call from :\(number.debugDescription)")
        Logger.connection.debug("incomingCallFrom HF Device: \(number)")
    }
    
    func handsFree(_ device: IOBluetoothHandsFreeAudioGateway!, hangup: NSNumber!) {
        Logger.connection.debug("hangup HF Device: \(hangup)")
    }
    
    func handsFree(_ device: IOBluetoothHandsFreeDevice!, subscriberNumber: String!) {
        Logger.connection.debug("subscriberNumber HF Device: \(subscriberNumber)")
    }
    
    
    
    
}

class HFAGDelegate:NSObject, IOBluetoothHandsFreeAudioGatewayDelegate{
    
}


class HFDelegate:NSObject, IOBluetoothHandsFreeDelegate{
    
}


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
    var handsFreeDevice:IOBluetoothHandsFreeDevice? = nil
    
    
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
    func update(handFreeDevice:IOBluetoothHandsFreeDevice?){
        self.handsFreeDevice = handFreeDevice
        if handFreeDevice != nil{
            self.devicename = handFreeDevice!.device.nameOrAddress
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
            Logger.connection.debug("Call setup mode idle")
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

/*
 
 call hold stated:
 0: No calls are on hold.
 1: A call is on hold and another is active.
 2: A call is on hold and no calls are active.
 
 callsetup mode:
 0: No calls are being set up.
 1: An incoming call is being set up.
 2: An outgoing call is being set up.
 3: The party receiving the call is being notified.
 
 battery:
 0-5, where 0 indicates a very low battery charge and 5 indicates a very high charge
 
direction:
 “0”: An outgoing call.
 “1”: An incoming call.
 
 call mode:
 “0”: A voice call.
 “1”: A data call.
 “2”: A fax call.

 call status:
 “0”: An active call.
 “1”: An active call that’s on hold.
 “2”: An outgoing call that’s dialing.
 “3”: An outgoing call that’s alerting the receiver.
 “4”: An incoming call.
 “5”: A call that’s waiting.
 
 
 Current call: Optional([AnyHashable("mulitiparty"): 0, AnyHashable("status"): 3, AnyHashable("number"): +917248750270, AnyHashable("index"): 1, AnyHashable("mode"): 0, AnyHashable("direction"): 0, AnyHashable("type"): 145])
 
 */

class SimpleTimer {
    static let shared = SimpleTimer()
    private var startTime: Date?
    private var timer: Timer?
    private var elapsedTimeString: String = "00:00:00"
    
    private init(){}
    
    func resetTimer() {
        self.stopTimer()
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTime()
        }
    }
    
    func stopTimer(){
        timer?.invalidate()
        self.elapsedTimeString = "00:00:00"
        timer = nil
    }
    
    func getElapsedTime()->String{
        return self.elapsedTimeString
    }
    
    private func updateTime() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        HFDState.shared.update(elapsedTimeString: self.elapsedTimeString)
    }
}
