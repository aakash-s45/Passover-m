import SwiftUI

/// A window that appears when an untrusted device initiates pairing.
/// Shows the SAS code and Confirm/Reject buttons.
struct PairingWindow: View {
    @EnvironmentObject var pairingManager: PairingManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            switch pairingManager.pairingState {
            case .awaitingSasConfirmation:
                sasView
            case .paired:
                pairedView
            case .error(let msg):
                errorView(msg)
            case .idle:
                Text("Waiting for pairing request…")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 360, height: 280)
        .padding()
    }
    
    private var sasView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(.blue)
            
            Text("Pairing Request")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("'\(pairingManager.pendingPeerName)' wants to pair.\nVerify the code matches on both devices:")
                .multilineTextAlignment(.center)
                .font(.body)
            
            Text(pairingManager.sasCode)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.vertical, 4)
            
            HStack(spacing: 16) {
                Button("Reject") {
                    pairingManager.rejectSas()
                    dismiss()
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
            
            Text("Paired!")
                .font(.title2)
                .fontWeight(.bold)
            
            Button("Done") {
                pairingManager.pairingState = .idle
                dismiss()
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                pairingManager.pairingState = .idle
                dismiss()
            }
        }
    }
}
