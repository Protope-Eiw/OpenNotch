//
//  NotchScale.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 2/23/26.
//

import SwiftUI

struct NotchScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

struct NotchHasHardwareNotchKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var notchScale: CGFloat {
        get { self[NotchScaleKey.self] }
        set { self[NotchScaleKey.self] = newValue }
    }

    var notchHasHardwareNotch: Bool {
        get { self[NotchHasHardwareNotchKey.self] }
        set { self[NotchHasHardwareNotchKey.self] = newValue }
    }
}
