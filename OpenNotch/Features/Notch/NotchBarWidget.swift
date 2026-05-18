import SwiftUI

enum NotchBarWidget: String, CaseIterable, Hashable {
    case networkSpeed = "networkSpeed"
    case cpu          = "cpu"
    case memory       = "memory"
    case disk         = "disk"

    var displayName: String {
        switch self {
        case .networkSpeed: return "Network"
        case .cpu:          return "CPU"
        case .memory:       return "Memory"
        case .disk:         return "Disk"
        }
    }
}

enum NetworkSpeedColorMode: String, CaseIterable, Hashable {
    case directional
    case unifiedWhite

    var titleKey: String {
        switch self {
        case .directional:  return "settings.notch.networkSpeedColor.directional"
        case .unifiedWhite: return "settings.notch.networkSpeedColor.unifiedWhite"
        }
    }
}
