//
//  NotchDisplayLocation.swift
//  OpenNotch
//
//  Created by Евгений Петрукович on 4/8/26.
//

import Foundation
import SwiftUI

enum NotchDisplayLocation: String, CaseIterable {
    case auto
    case builtIn
    case manual

    var title: String {
        switch self {
        case .auto:
            return "settings.general.display.auto"
        case .builtIn:
            return "settings.general.display.builtin"
        case .manual:
            return "settings.general.display.manual"
        }
    }

    var symbolName: String {
        switch self {
        case .auto:
            return "cursorarrow.motionlines"
        case .builtIn:
            return "macbook.gen2"
        case .manual:
            return "display.2"
        }
    }
}
