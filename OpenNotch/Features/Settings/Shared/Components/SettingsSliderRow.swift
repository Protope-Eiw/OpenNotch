//
//  SliderRow.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsSliderRow: View {
    let title: String
    let description: String?
    let range: ClosedRange<Double>
    let step: Double
    let fractionLength: Int
    let suffix: String?
    let accessibilityIdentifier: String?
    
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                
                Spacer()
                
                AnimatedLevelText(
                    value: value,
                    fontSize: 12,
                    fractionLength: fractionLength,
                    suffix: suffix,
                    color: .secondary
                )
            }
            
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 6)
        .modifier(SettingsAccessibilityModifier(identifier: accessibilityIdentifier))
        .modifier(SettingsAnnotation(description: description))
    }
}
