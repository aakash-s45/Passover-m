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


class HFAGDelegate:NSObject, IOBluetoothHandsFreeAudioGatewayDelegate{
    
}


class HFDelegate:NSObject, IOBluetoothHandsFreeDelegate{
    
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
