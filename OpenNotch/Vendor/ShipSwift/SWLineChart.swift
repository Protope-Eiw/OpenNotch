import SwiftUI
import Charts

struct SWLineChart<CategoryType: Hashable & Plottable>: View {
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

    struct ReferenceLine {
        let value: Double
        let label: String?
        let color: Color
        let style: StrokeStyle

        init(
            value: Double,
            label: String? = nil,
            color: Color = .secondary,
            style: StrokeStyle = StrokeStyle(lineWidth: 1, dash: [5, 3])
        ) {
            self.value = value
            self.label = label
            self.color = color
            self.style = style
        }
    }

    let dataPoints: [DataPoint]
    let colorMapping: [CategoryType: Color]
    var referenceLines: [ReferenceLine] = []
    var interpolationMethod: InterpolationMethod = .catmullRom
    var showPointMarkers: Bool = false
    var yDomain: ClosedRange<Double>?
    var visibleSeconds: Int = 60
    var chartHeight: CGFloat = 120
    var title: String?

    @State private var animationProgress: Double = 0

    private var effectiveYDomain: ClosedRange<Double>? {
        if let yDomain = yDomain { return yDomain }
        let allValues = dataPoints.map(\.value) + referenceLines.map(\.value)
        guard let minVal = allValues.min(), let maxVal = allValues.max(), maxVal > 0 else { return nil }
        return min(minVal, 0)...maxVal
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
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value * animationProgress)
                    )
                    .foregroundStyle(by: .value("Category", point.category))
                    .interpolationMethod(interpolationMethod)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if showPointMarkers {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value * animationProgress)
                        )
                        .foregroundStyle(by: .value("Category", point.category))
                        .symbolSize(20)
                    }
                }

                ForEach(Array(referenceLines.enumerated()), id: \.offset) { _, line in
                    RuleMark(y: .value("Reference", line.value * animationProgress))
                        .foregroundStyle(line.color)
                        .lineStyle(line.style)
                        .annotation(position: .top, alignment: .leading) {
                            if let label = line.label {
                                Text(label)
                                    .font(.caption2)
                                    .foregroundStyle(line.color)
                            }
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

extension SWLineChart where CategoryType == String {
    init(
        dataPoints: [DataPoint],
        colorMapping: [String: Color],
        referenceLines: [ReferenceLine] = [],
        interpolationMethod: InterpolationMethod = .catmullRom,
        showPointMarkers: Bool = false,
        yDomain: ClosedRange<Double>? = nil,
        visibleSeconds: Int = 60,
        chartHeight: CGFloat = 120,
        title: String? = nil
    ) {
        self.dataPoints = dataPoints
        self.colorMapping = colorMapping
        self.referenceLines = referenceLines
        self.interpolationMethod = interpolationMethod
        self.showPointMarkers = showPointMarkers
        self.yDomain = yDomain
        self.visibleSeconds = visibleSeconds
        self.chartHeight = chartHeight
        self.title = title
    }
}
