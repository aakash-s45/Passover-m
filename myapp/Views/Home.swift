import SwiftUI

struct Home: View{
    @EnvironmentObject var bluetoothClient:BluetoothL2capClient
    
    var body: some View {
        VStack{
            Text(bluetoothClient.status).font(.title)
            if bluetoothClient.isConnected {
                HStack{
                    Text(bluetoothClient.deviceName).font(.title).bold()
                    Spacer()
                    Image(systemName: "trash.fill").onTapGesture {
                        bluetoothClient.disconnect()
                    }.font(.title2)
                }
            }
            else{
                ScanResult()
                if bluetoothClient.status != "Scanning..."{
                    Button("Scan"){
                        _ = bluetoothClient.startScan()
                    }
                }
                
            }
        }.padding()
    }
}



/*

 if connected:
    show disconnect + remove
 else:
    start scan
    show devices
    if saved:
        auto connect to saved device
    else select:
        save + connect

 */


