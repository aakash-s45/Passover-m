//
//  SavedDevice.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct SavedDevice: View {
    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
    
    var body: some View {
        VStack{
            Text("Saved Device").padding(.bottom)
            if(!bluetoothViewModel.savedDevice.isEmpty){
                HStack(alignment: .center){
                    Image(systemName: "candybarphone").imageScale(.large)
                    Text(bluetoothViewModel.savedDevice.last ?? "Unknown").font(.title2).bold()
                    Spacer()
                    Image(systemName: "trash.circle").imageScale(.large).onTapGesture {
                        AppRepository.shared.clearDevice()
                        bluetoothViewModel.update(is_device: false)
                        bluetoothViewModel.update(savedDevice: [])
                    }
                }
            }
        }
    }
}

#Preview {
    SavedDevice()
}
