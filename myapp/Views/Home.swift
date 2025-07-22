////
////  Home.swift
////  myapp
////
////  Created by Aakash Solanki on 01/09/24.
////
//
//import SwiftUI
//
//struct Home: View {
//    @EnvironmentObject var bluetoothViewModel:ConnectionViewModel
//    
//    // For Classic Bluetooth (RFCOMM)
//    @StateObject private var classicService = BluetoothClassicService()
//    @State private var dataToSend: String = ""
//
//    var body: some View {
//        VStack {
//            // Existing BLE UI
//            Group {
//                Button("Start Receiving") {
//                    AppRepository.shared.fileReceiver?.startServer()
//                }
//                Button("Stop Server") {
//                    AppRepository.shared.fileReceiver?.stopServer()
//                }
//                
//                if bluetoothViewModel.is_powered_on{
//                    if bluetoothViewModel.is_connected{
//                        ConnectedDevice()
//                    }
//                    else{
//                        if bluetoothViewModel.is_device_saved{
//                            SavedDevice()
//                        }
//                        else{
//                            if bluetoothViewModel.is_scanning{
//                                VStack{
//                                    ScanResult()
//                                }
//                            }
//                            else{
//                                VStack{
//                                    if !bluetoothViewModel.scanResult.isEmpty{
//                                        ScanResult()
//                                    }
//                                    else{
//                                        Text("No device found")
//                                    }
//                                    Button("Scan"){
//                                        AppRepository.shared.scan()
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//                else{
//                    Text("Turn on Bluetooth")
//                }
//            }
//            
//            Divider().padding(.vertical)
//            
//            // New Classic Bluetooth (RFCOMM) UI
//            VStack {
//                Text("Classic Bluetooth (RFCOMM)")
//                    .font(.headline)
//                
//                Text(classicService.connectionStatus)
//                    .padding()
//                
//                if classicService.connectedSocket == nil {
//                    // Scanning and Connection UI
//                    HStack {
//                        Button(classicService.isScanning ? "Scanning..." : "Scan for Classic Devices") {
//                            classicService.scanForDevices()
//                        }
//                        .disabled(classicService.isScanning)
//                    }
//                    
//                    List(classicService.discoveredDevices, id: \.address) { device in
//                        HStack {
//                            Text(device.name ?? "Unknown Device")
//                            Spacer()
//                            Text(device.address.description)
//                            Button("Connect") {
//                                classicService.connect(to: device)
//                            }
//                        }
//                    }
//                    .frame(height: 200)
//                    
//                } else {
//                    // Connected UI
//                    VStack {
//                        HStack {
//                            TextField("Enter data to send", text: $dataToSend)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                            
//                            Button("Send") {
//                                if let data = dataToSend.data(using: .utf8) {
//                                    classicService.send(data: data)
//                                }
//                            }
//                        }
//                        
//                        Button("Disconnect") {
//                            classicService.disconnect()
//                        }
//                        .padding(.top)
//                        
//                        ScrollView {
//                            Text("Received Data:")
//                            Text(String(data: classicService.receivedData, encoding: .utf8) ?? "Invalid UTF-8 data")
//                                .font(.body.monospaced())
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                        }
//                    }
//                }
//            }
//            .padding()
//        }
//        .padding()
//    }
//}
//
