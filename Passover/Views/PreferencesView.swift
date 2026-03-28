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
    @EnvironmentObject var pairingManager: PairingManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Pairing state
            switch pairingManager.pairingState {
            case .idle:
                idleView
            case .awaitingSasConfirmation:
                sasConfirmationView
            case .paired:
                pairedView
            case .error(let message):
                errorView(message: message)
            }
            
            Divider()
            
            // Trusted devices list
            trustedDevicesView
        }
        .padding()
    }
    
    private var idleView: some View {
        VStack(spacing: 12) {
            Text("Ready to Pair")
                .font(.headline)
            Text("Open the Passover app on your phone and tap 'Pair New Device'.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var sasConfirmationView: some View {
        VStack(spacing: 16) {
            Text("Verify Connection")
                .font(.headline)
            
            Text("Confirm that '\(pairingManager.pendingPeerName)' shows the same code:")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Text(pairingManager.sasCode)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .padding()
            
            HStack(spacing: 16) {
                Button("Reject") {
                    pairingManager.rejectSas()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Confirm") {
                    pairingManager.confirmSas()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var pairedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Device Paired Successfully!")
                .font(.headline)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(message)
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
    
    private var trustedDevicesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trusted Devices")
                .font(.headline)
            
            if pairingManager.trustedPeers.isEmpty {
                Text("No paired devices yet.")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                ForEach(pairingManager.trustedPeers) { peer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peer.deviceName)
                                .font(.body)
                            Text(String(peer.deviceId.prefix(8)) + "…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            pairingManager.removeTrustedPeer(deviceId: peer.deviceId)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
