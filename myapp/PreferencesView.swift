//
//  PreferencesView.swift
//  myapp
//
//  Created by Aakash Solanki on 12/05/24.
//

import Foundation
import SwiftUI
import CoreBluetooth


struct NewWindow: View {
    @EnvironmentObject var bleViewModel:BLEViewModel
    
    var body: some View {
        let currentBleDevice = bleViewModel.currentDevice
        var connected = true
        VStack{
            if currentBleDevice != nil{
                if(currentBleDevice?.state != CBPeripheralState.connected){
                    CurrentDevice(peripheral: currentBleDevice!, rssi: -100).onAppear(perform: {connected = false})
                }
                else{
                    CurrentDevice(peripheral: currentBleDevice!, rssi: 0).onAppear(perform: {connected = true})
                }
                
                HStack{
                    if connected{
                        Button("Disconnect device", action: {
                            bleViewModel.disconnect()
                        })
                    }
                    else{
                        Button("Connect device", action: {
                            bleViewModel.connectToDevice(peripheral: currentBleDevice!)
                            connected = true
                        })
                    }

                    Button("Remove current device", action: {
                        bleViewModel.disconnect()
                        bleViewModel.clearIdentifiers()
                    })
                }
            }
            else if !bleViewModel.isScanning{
                Button("Start Scan", action: {
                    bleViewModel.disconnect()
                })
            }
            else if bleViewModel.isScanning{
                ScanResults()
            }
            Spacer(minLength: 10)
            
        }
    }
}
