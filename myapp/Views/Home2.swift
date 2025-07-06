import SwiftUI


struct Home2:View{
    @EnvironmentObject var bluetoothManager:BluetoothManager
    
    var body: some View{
        VStack(spacing: 20) {
            Text("\(bluetoothManager.state)")
                .font(.title)
//            Text("Info: \(bluetoothManager)")
            ScanResult()
        
            Button("Disconnect") {
                bluetoothManager.disconnect()
            }
        }
        .padding()
    }
}

