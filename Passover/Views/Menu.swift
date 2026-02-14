import SwiftUI

struct Menu: View{
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack{
            Button("Preferences"){
                openWindow(id: "preferences-window")
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }.padding()
    }
}
