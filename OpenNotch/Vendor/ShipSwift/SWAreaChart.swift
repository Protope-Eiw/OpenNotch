import SwiftUI
import Charts

struct SWAreaChart<CategoryType: Hashable & Plottable>: View {
    struct DataPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
        let category: CategoryType

        init(id: UUID = UUID(), date: Date, value: Double, category: CategoryType) {
            self.id = id
            self.date = date
            self.value = value
            self.category = category
        }
    }

    let dataPoints: [DataPoint]
    let colorMapping: [CategoryType: Color]
    var showLineOverlay: Bool = true
    var interpolationMethod: InterpolationMethod = .catmullRom
    var gradientOpacity: Double = 0.15
    var yDomain: ClosedRange<Double>?
    var visibleSeconds: Int = 60
    var chartHeight: CGFloat = 120
    var title: String?

    @State private var animationProgress: Double = 0

    private var effectiveYDomain: ClosedRange<Double>? {
        if let yDomain = yDomain { return yDomain }
        guard !dataPoints.isEmpty else { return nil }
        guard let singleMax = dataPoints.map(\.value).max(), singleMax > 0 else { return nil }
        return 0...singleMax
    }

    private var chartXDomain: ClosedRange<Date> {
        let now = Date()
        let start = now.addingTimeInterval(-Double(visibleSeconds))
        return start...now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Chart {
                ForEach(dataPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value * animationProgress)
                    )
                    .foregroundStyle(by: .value("Category", point.category))
                    .interpolationMethod(interpolationMethod)
                    .opacity(gradientOpacity)

                    if showLineOverlay {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value * animationProgress)
                        )
                        .foregroundStyle(by: .value("Category", point.category))
                        .interpolationMethod(interpolationMethod)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: Array(colorMapping.keys),
                range: Array(colorMapping.values)
            )
            .chartXScale(domain: chartXDomain)
            .applyOptionalYDomain(effectiveYDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.second())
                }
            }
            .chartLegend(.hidden)
            .frame(height: chartHeight)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func applyOptionalYDomain(_ domain: ClosedRange<Double>?) -> some View {
        if let domain = domain {
            self.chartYScale(domain: domain)
        } else {
            self
        }
    }
}

extension SWAreaChart where CategoryType == String {
    init(
        dataPoints: [DataPoint],
        colorMapping: [String: Color],
        showLineOverlay: Bool = true,
        interpolationMethod: InterpolationMethod = .catmullRom,
        gradientOpacity: Double = 0.15,
        yDomain: ClosedRange<Double>? = nil,
        visibleSeconds: Int = 60,
        chartHeight: CGFloat = 120,
        title: String? = nil
    ) {
        self.dataPoints = dataPoints
        self.colorMapping = colorMapping
        self.showLineOverlay = showLineOverlay
        self.interpolationMethod = interpolationMethod
        self.gradientOpacity = gradientOpacity
        self.yDomain = yDomain
        self.visibleSeconds = visibleSeconds
        self.chartHeight = chartHeight
        self.title = title
    }
}
