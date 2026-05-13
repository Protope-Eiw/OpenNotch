import SwiftUI

struct SWShimmer<Content: View>: View {
    @State private var animate = false

    var duration: Double = 2.0
    var delay: Double = 1.0

    @ViewBuilder let content: () -> Content

    init(
        duration: Double = 2.0,
        delay: Double = 1.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [.clear, .clear, .white.opacity(0.15), .clear, .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        content()
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.5
                    gradient
                        .frame(width: bandWidth)
                        .offset(x: animate ? geo.size.width + bandWidth : -bandWidth * 1.5)
                        .animation(
                            .linear(duration: duration)
                            .delay(delay)
                            .repeatForever(autoreverses: false),
                            value: animate
                        )
                }
                .clipped()
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                animate = true
            }
    }
}
