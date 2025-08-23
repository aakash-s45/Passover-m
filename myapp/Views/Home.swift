import SwiftUI

struct Home: View{
    @EnvironmentObject var bluetoothClient:BluetoothL2capClient
    
    var body: some View {
        VStack{
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
                Text(bluetoothClient.status).font(.title)
                ScanResult()
                if bluetoothClient.status != "Scanning..."{
                    Button("Scan"){
                        bluetoothClient.startScan()
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


