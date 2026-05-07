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
