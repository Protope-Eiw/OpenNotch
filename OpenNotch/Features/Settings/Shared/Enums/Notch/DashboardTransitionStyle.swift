import Foundation

enum DashboardTransitionStyle: String, CaseIterable {
    case slide
    case fade

    var title: String {
        switch self {
        case .slide: return "Slide"
        case .fade:  return "Fade"
        }
    }
}
