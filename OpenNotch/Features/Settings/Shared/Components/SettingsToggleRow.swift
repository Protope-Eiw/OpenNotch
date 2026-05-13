//
//  SettingsToggleRow.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsToggleRow: View {
    let title: String
    let description: String?
    let systemImage: String?
    let imageName: String?
    let color: Color
    let showIcon: Bool
    let accessibilityIdentifier: String?

    @Binding var isOn: Bool

    init(
        title: String,
        description: String? = nil,
        systemImage: String,
        color: Color,
        isOn: Binding<Bool>,
        showIcon: Bool = true,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.imageName = nil
        self.color = color
        self.showIcon = showIcon
        self._isOn = isOn
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    init(
        title: String,
        description: String? = nil,
        imageName: String,
        color: Color,
        isOn: Binding<Bool>,
        showIcon: Bool = true,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = nil
        self.imageName = imageName
        self.color = color
        self.showIcon = showIcon
        self._isOn = isOn
        self.accessibilityIdentifier = accessibilityIdentifier
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: 12) {
                if showIcon {
                    if let systemImage {
                        SettingsIconBadge(
                            systemImage: systemImage,
                            tint: color,
                            size: 30,
                            iconSize: 14,
                            cornerRadius: 9
                        )
                    } else if let imageName {
                        SettingsIconBadge(
                            imageName: imageName,
                            tint: color,
                            size: 30,
                            iconSize: 14,
                            cornerRadius: 9
                        )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                }
                
                Spacer()
            }
        }
        .toggleStyle(CustomToggleStyle())
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
        .modifier(SettingsAnnotation(description: description))
    }
}
