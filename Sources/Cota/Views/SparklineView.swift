import SwiftUI

struct SparklineView: View {
    let data: [Decimal]
    let color: Color

    var body: some View {
        if data.count >= 2 {
            SparklinePath(values: data.map { NSDecimalNumber(decimal: $0).doubleValue })
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 50, height: 16)
                .accessibilityLabel("Price trend")
                .accessibilityValue(trendDescription)
        }
    }

    private var trendDescription: String {
        guard let first = data.first, let last = data.last else { return "No data" }
        if last > first { return "Trending up" }
        if last < first { return "Trending down" }
        return "Stable"
    }
}

private struct SparklinePath: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard let min = values.min(), let max = values.max(), max > min else {
            return Path { path in
                path.move(to: CGPoint(x: 0, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            }
        }

        let stepX = rect.width / CGFloat(values.count - 1)
        let rangeY = max - min

        return Path { path in
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = rect.height - (CGFloat((value - min) / rangeY) * rect.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
