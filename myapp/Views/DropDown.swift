import SwiftUI


struct DropDownMenu: View {
  @State private var isExpanded: Bool = false
  @State private var selectedOption: String = "Select"
  let options = ["Connect", "Disconnect", "Remove"]

  var body: some View {
      DisclosureGroup("",isExpanded: $isExpanded) {
      VStack {
        ForEach(options, id: \.self) { option in
          Text(option)
            .padding()
            .onTapGesture {
              selectedOption = option
              isExpanded = false
            }
        }
      }
      }
//    .padding()
    .cornerRadius(8)
  }
}


