import SwiftUI

struct SettingsMenuRow<Option: Hashable>: View {
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
            }

            Spacer(minLength: 12)

            Color.clear
                .frame(width: 160)
                .overlay(alignment: .leading) {
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button {
                                selection = option
                            } label: {
                                HStack {
                                    Text(optionTitle(option))
                                    if option == selection {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(optionTitle(selection))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
        }
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
        .modifier(SettingsAnnotation(description: description))
    }
}
