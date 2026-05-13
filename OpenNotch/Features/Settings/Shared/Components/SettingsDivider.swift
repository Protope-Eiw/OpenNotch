import SwiftUI

struct SettingsDivider: View {
    var indented = false
    var indentSize: CGFloat = 43
    var opacity: Double = 0.6

    var body: some View {
        Divider()
            .opacity(opacity)
            .padding(.leading, indented ? indentSize : 0)
    }
}
