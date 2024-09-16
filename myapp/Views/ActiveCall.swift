//
//  ActiveCall.swift
//  myapp
//
//  Created by Aakash Solanki on 03/09/24.
//

import SwiftUI

struct ActiveCall: View {
    @EnvironmentObject var hfdState:HFDState
    var body: some View {
        let title = hfdState.callMapping["number"]!
        let status = hfdState.callMapping["status"]!
        let mode = hfdState.callMapping["mode"]!
        let timer = hfdState.elapsedTimeString
        VStack{
            HStack(alignment: .center){
                Image(systemName: getImage(title: title)).imageScale(.large).font(.system(size: 30))
                VStack(alignment: .leading){
                    Text(title)
                    if status == "talking"{
                        Text(timer).foregroundColor(.gray)
                    }
                    else{
                        Text(status).foregroundColor(.gray)
                    }
                }
                Spacer().frame(width:50)
                HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 5){
                    if mode == "in"{
                        Image(systemName: "arrow.down.backward").font(.system(size: 15))
                            .foregroundStyle(.green)
                    }
                    else{
                        Image(systemName: "arrow.up.right").font(.system(size: 15)).foregroundStyle(.blue)
                    }
                    SignalStrength(active: hfdState.signal, scale: 2.5)
                    Image(systemName: getBatteryString(charge: self.hfdState.battery))
                }
                Image(systemName: "phone.down.circle.fill").font(.system(size: 20)).foregroundStyle(.red).onTapGesture {
                    AppRepository.shared.bluetoothClient?.hfDevice?.endCall()
                }.padding(.horizontal)

            }
            Spacer().frame(height:28)
        }
        .frame(width: 320, height: 70)
    }
}

func getImage(title: String) -> String {
//    guard let firstChar = title.first?.lowercased() else {
//        return "person.circle.fill" // Fallback in case title is empty
//    }
    
    return "person.circle.fill"
//    return "\(firstChar).circle.fill"
}

#Preview {
    ActiveCall()
}
