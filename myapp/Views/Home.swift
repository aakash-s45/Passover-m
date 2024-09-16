//
//  Home.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct Home: View {
    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
    @EnvironmentObject var handsfreeDeviceState:HFDState
    var body: some View {
        if bluetoothViewModel.is_powered_on{
            if bluetoothViewModel.is_connected{
                ConnectedDevice()
            }
            else if(handsfreeDeviceState.is_connected){
                ConnectedDevice()
            }
            else{
                if bluetoothViewModel.is_device_saved{
                    SavedDevice()
                }
                else{
                    if bluetoothViewModel.is_scanning{
                        VStack{
                            ScanResult()
                        }
                    }
                    else{
                        VStack{
                            if !bluetoothViewModel.scanResult.isEmpty{
                                ScanResult()
                            }
                            else{
                                Text("No device found")
                            }
                            Button("Scan"){
                                AppRepository.shared.scan()
                            }
                        }
                    }
                }
            }
        }
        else{
            Text("Turn on Bluetooth")
        }
    }
}

#Preview {
    Home()
}
