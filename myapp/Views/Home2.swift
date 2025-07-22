//import SwiftUI
//
//struct Home2: View {
//    // For BLE (existing)
//    @EnvironmentObject var bluetoothManager: BluetoothManager
//    
//    // For Classic Bluetooth (RFCOMM)
//    @StateObject private var classicService = BluetoothClassicService()
//    @State private var dataToSend: String = ""
//    
//    var body: some View {
//        VStack(spacing: 10) {
//            
//            // --- Existing BLE UI ---
//            Text("Bluetooth Low Energy")
//                .font(.headline)
//            Text("State: \(bluetoothManager.state.description)")
//                .font(.subheadline)
//            ScanResult() // This seems to be for BLE results
//            
//            Divider().padding(.vertical, 10)
//            
//            // --- New Classic Bluetooth (RFCOMM) UI ---
//            Text("Classic Bluetooth (RFCOMM)")
//                .font(.headline)
//            
//            Text(classicService.connectionStatus)
//                .font(.subheadline)
//                .padding(.bottom, 5)
//            
//            if classicService.connectedSocket == nil {
//                // --- Disconnected State ---
//                Button(classicService.isScanning ? "Scanning..." : "Scan for Classic Devices") {
//                    classicService.scanForDevices()
//                }
//                .disabled(classicService.isScanning)
//                
//                List(classicService.discoveredDevices, id: \.address) { device in
//                    HStack {
//                        VStack(alignment: .leading) {
//                            Text(device.name ?? "Unknown Device")
//                            Text(device.address.description).font(.caption)
//                        }
//                        Spacer()
//                        Button("Connect") {
//                            classicService.connect(to: device)
//                        }
//                    }
//                }
//                .frame(minHeight: 150)
//                
//            } else {
//                // --- Connected State ---
//                VStack {
//                    HStack {
//                        TextField("Enter data to send", text: $dataToSend)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                        
//                        Button("Send") {
//                            if let data = dataToSend.data(using: .utf8) {
//                                classicService.send(data: data)
//                                dataToSend = ""
//                            }
//                        }
//                    }
//                    
//                    ScrollView {
//                        VStack(alignment: .leading) {
//                            Text("Received Data:")
//                                .bold()
//                            Text(String(data: classicService.receivedData, encoding: .utf8) ?? "---")
//                                .font(.body.monospaced())
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .padding(5)
//                                .background(Color.secondary.opacity(0.2))
//                                .cornerRadius(5)
//                        }
//                    }
//                    .frame(minHeight: 100)
//
//                    Button("Disconnect from Classic Device") {
//                        classicService.disconnect()
//                    }
//                    .padding(.top)
//                }
//            }
//        }
//        .padding()
//    }
//}
//
//// Add a description to the BluetoothConnectionState for better display
//extension BluetoothConnectionState {
//    var description: String {
//        switch self {
//        case .idle:
//            return "Idle"
//        case .scanning:
//            return "Scanning"
//        case .connecting(let peripheral):
//            return "Connecting to \(peripheral.name)"
//        case .connected(let peripheral):
//            return "Connected to \(peripheral.name)"
//        case .powerOff:
//            return "Bluetooth Powered Off"
//        }
//    }
//}
//
