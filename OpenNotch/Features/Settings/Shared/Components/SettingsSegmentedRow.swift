import SwiftUI

struct SettingsSegmentedRow<Option: Hashable>: View {
    let title: String
    let description: String?
    let options: [Option]
    let optionTitle: (Option) -> String
    let accessibilityIdentifier: String?

    @Binding var selection: Option

    init(
        title: String,
        description: String? = nil,
        options: [Option],
        optionTitle: @escaping (Option) -> String,
        accessibilityIdentifier: String? = nil,
        selection: Binding<Option>
    ) {
        self.title = title
        self.description = description
        self.options = options
        self.optionTitle = optionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self._selection = selection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option))
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
    }
}
