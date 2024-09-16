//
//  ConnectedDevice.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct ConnectedDevice: View {
    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
    @EnvironmentObject var handsFreeDeviceState:HFDState
    
    var body: some View {
        VStack(alignment: .leading){
            HStack(alignment: .bottom){
                if bluetoothViewModel.is_connected{
                    Image(systemName: "ellipsis.message.fill").imageScale(.medium).foregroundColor(.gray)
                }
                if handsFreeDeviceState.is_connected{
                    Image(systemName: "phone.down.waves.left.and.right").imageScale(.medium).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: handsFreeDeviceState.batteryText).imageScale(.medium)
                    SignalStrength(active: handsFreeDeviceState.signal, scale: 2.5)
                }
                else{
                    Spacer()
                }
            }.padding(.bottom)
            HStack(alignment: .center){
                Image(systemName: "candybarphone").imageScale(.large).foregroundColor(.green)
                Text(bluetoothViewModel.deviceName)
                    .font(.title2)
                    .bold()
                Spacer()
                Image(systemName: "trash.circle").imageScale(.large).foregroundColor(.gray).onTapGesture {
                    AppRepository.shared.stop()
                }
//                DropDownMenu()
            }
        }
    }
}

#Preview {
    ConnectedDevice()
}
