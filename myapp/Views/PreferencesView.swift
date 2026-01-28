import SwiftUI


struct PreferencesView: View {
    @State private var selectedTab = 0
    let tabs = ["Setup", "Notifications"]

    var body: some View {
        CustomTabView(content: [
            (title: "Setup",
             icon: "keyboard",
             view: AnyView(SetupView().scaledToFill())
            ),
            (title: "Notifications",
             icon: "bell.badge",
             view: AnyView(Text("Hello1").scaledToFill())
            )
        ])
    }
}


struct SetupView: View {
    @EnvironmentObject var pairingmanager: PairingManager
    var body: some View {
        if pairingmanager.isKeySaved{
            VStack{
                Text("Key is saved!")
                Button("Reset"){
                    pairingmanager.forgetPermanentKey()
                }
            }
        }
        else{
            HStack(alignment: .top, spacing: 20){
                VStack{
                    pairingmanager.qrCode?.resizable().interpolation(.none).scaledToFit()
                }
                VStack(alignment: .leading, spacing: 20){
                    Text("1. Make sure both devices are on the same WIFI").bold()
                    Text("2. Scan the QR Code on your phone").bold()
                    Text("3. Wait for the magic to happen!").bold()
                }
            }
        }
    }
}

