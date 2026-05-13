import SwiftUI

struct SettingsAnnotation: ViewModifier {
    let description: String?

    func body(content: Content) -> some View {
        if let description {
            VStack(alignment: .leading, spacing: 2) {
                content
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            content
        }
    }
}
