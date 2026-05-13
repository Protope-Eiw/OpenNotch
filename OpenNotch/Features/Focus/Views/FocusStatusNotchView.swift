//
//  FocusStatusNotchView.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct FocusOnNotchView: View {
    let style: FocusAppearanceStyle

    var body: some View {
        FocusStatusNotchView(title: "On", style: .info, tint: .indigo, focusStyle: style)
    }
}

struct FocusOffNotchView: View {
    let style: FocusAppearanceStyle

    var body: some View {
        FocusStatusNotchView(title: "Off", style: .neutral, tint: .gray.opacity(0.6), focusStyle: style)
    }
}

private struct FocusStatusNotchView: View {
    @Environment(\.notchScale) var scale

    let title: String
    let badgeStyle: SWStatusBadgeStyle
    let tint: Color
    let focusStyle: FocusAppearanceStyle

    init(title: String, style: SWStatusBadgeStyle, tint: Color, focusStyle: FocusAppearanceStyle) {
        self.title = title
        self.badgeStyle = style
        self.tint = tint
        self.focusStyle = focusStyle
    }

    var body: some View {
        Group {
            if focusStyle == .iconsOnly {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .bold))

                    Spacer(minLength: 0)
                }
            } else {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .bold))

                    Spacer()

                    SWStatusBadge(text: title, style: badgeStyle)
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
