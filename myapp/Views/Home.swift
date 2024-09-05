//
//  Home.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI

struct Home: View {
    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
    var body: some View {
        if bluetoothViewModel.is_powered_on{
            if bluetoothViewModel.is_connected{
                ConnectedDevice()
            }
            else if(bluetoothViewModel.is_hf_connected){
                ConnectedDevice()
            }
            else{
                if bluetoothViewModel.is_device_saved{
                    SavedDevice()
                }
                else{
                    if bluetoothViewModel.is_scanning{
                        ScanResult()
                    }
                    else{
                        if bluetoothViewModel.scanResult.isEmpty{
                            Text("No device found")
                        }
                        else{
                            ScanResult()
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
