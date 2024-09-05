//
//  CallAlert.swift
//  myapp
//
//  Created by Aakash Solanki on 03/09/24.
//

import SwiftUI

struct CallAlert:View {
    @EnvironmentObject var hfdState:HFDState
    var body: some View {
        let title = hfdState.callMapping["number"]!

        VStack{
            HStack(alignment: .center){
                Image(systemName: getImage(title: title)).imageScale(.large).font(.system(size: 30))
                VStack(alignment: .leading){
                    Text(title)
                    Text("from \(hfdState.devicename)").foregroundColor(.gray)
                }
                Spacer().frame(width:50)
                VStack(alignment: .leading){
                    Button("Accept", action: {
                        HFDState.shared.handsFreeDevice?.acceptCall()
                    })
                    Button("Reject", action: {
                        HFDState.shared.handsFreeDevice?.endCall()
                    })
                }

            }
            Spacer().frame(height:28)
        }
        .frame(width: 300, height: 70)
    }
}

#Preview {
    CallAlert()
}
