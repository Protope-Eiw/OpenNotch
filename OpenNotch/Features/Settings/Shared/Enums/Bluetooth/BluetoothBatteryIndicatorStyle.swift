import SwiftUI

enum BluetoothBatteryIndicatorStyle: String, CaseIterable {
    case percent
    case circle

    var title: String {
        switch self {
        case .percent:
            return "Percent"
        case .circle:
            return "Circle"
        }
    }
}
