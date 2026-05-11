import SwiftUI

struct PillRightWidgetView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    let widgetsRaw: String
    let ringSize: CGFloat

    var body: some View {
        let widgets = widgetsRaw.split(separator: ",").compactMap { NotchBarWidget(rawValue: String($0)) }
        if widgets.isEmpty {
            Color.clear.frame(width: CGFloat(ringSize * 2 + 8), height: 1)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(widgets.prefix(2)), id: \.self) { widget in
                    PillRingView(systemMonitorViewModel: systemMonitorViewModel, widget: widget, ringSize: ringSize)
                }
            }
        }
    }
}
