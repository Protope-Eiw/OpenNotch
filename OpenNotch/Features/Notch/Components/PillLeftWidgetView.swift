import SwiftUI

struct PillLeftWidgetView: View {
    @ObservedObject var systemMonitorViewModel: SystemMonitorViewModel
    @ObservedObject var pomodoroViewModel: PomodoroViewModel
    let widgetsRaw: String
    let ringSize: CGFloat

    var body: some View {
        let widgets = widgetsRaw.split(separator: ",").compactMap { NotchBarWidget(rawValue: String($0)) }
        if pomodoroViewModel.state != .idle {
            HStack(spacing: 4) {
                Image(systemName: pomodoroViewModel.phase == .work ? "flame.fill" : "cup.and.heat.waves.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(pomodoroViewModel.phase == .work ? .orange : .mint)
                Text(pomodoroViewModel.timeString)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(pomodoroViewModel.phase == .work ? Color.orange : Color.mint)
            }
        } else if widgets.isEmpty {
            Color.clear.frame(width: 65, height: 1)
        } else {
            HStack(spacing: 6) {
                ForEach(Array(widgets.prefix(2)), id: \.self) { widget in
                    PillRingView(systemMonitorViewModel: systemMonitorViewModel, widget: widget, ringSize: ringSize)
                }
            }
        }
    }
}
