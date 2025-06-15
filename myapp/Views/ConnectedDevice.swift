//
//  ConnectedDevice.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct ConnectedDevice: View {
    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
    
    var body: some View {
        VStack(alignment: .leading){
            HStack(alignment: .bottom){
                if bluetoothViewModel.is_connected{
                    Image(systemName: "ellipsis.message.fill").imageScale(.medium).foregroundColor(.gray)
                }
                Spacer()
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
            }
        }
    }
}

#Preview {
    ConnectedDevice()
}
