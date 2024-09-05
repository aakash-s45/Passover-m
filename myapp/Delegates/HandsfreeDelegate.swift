import os
import IOBluetooth

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
