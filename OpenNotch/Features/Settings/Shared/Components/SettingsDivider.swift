import SwiftUI

struct SettingsDivider: View {
    var indented = false

    var body: some View {
        Divider()
            .opacity(0.6)
            .padding(.leading, indented ? 43 : 0)
    }
}
