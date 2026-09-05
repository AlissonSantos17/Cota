import SwiftUI

struct SparklineView: View {
    let data: [Decimal]
    let color: Color

    static let width: CGFloat = 60
    static let height: CGFloat = 24

    var body: some View {
        if let domain = SparklineDomain(values: values) {
            ZStack {
                SparklineReference(domain: domain)
                    .stroke(
                        Color(nsColor: .separatorColor),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )

                SparklinePath(values: values, domain: domain)
                    .stroke(
                        color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: Self.width, height: Self.height)
            .accessibilityLabel("Price trend")
            .accessibilityValue(trendDescription)
        }
    }

    private var values: [Double] {
        data.map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    private var trendDescription: String {
        guard let first = data.first, let last = data.last else { return "No data" }
        if last > first { return "Trending up" }
        if last < first { return "Trending down" }
        return "Stable"
    }
}

/// Vertical scale for a sparkline, anchored to the opening value of the period.
///
/// Auto-scaling every series to its own min/max makes a pair that moved 0.02%
/// look as agitated as one that moved 0.5%. When the whole series fits inside
/// `minimumRange`, the scale falls back to a fixed window around the opening
/// value, so a flat series reads as flat.
struct SparklineDomain {
    let lower: Double
    let upper: Double
    let open: Double

    private static let minimumRange = 0.005
    private static let floorHalfRange = 0.0025

    init?(values: [Double]) {
        guard values.count >= 2,
            let low = values.min(),
            let high = values.max(),
            let open = values.first,
            open != 0
        else {
            return nil
        }

        self.open = open

        if (high - low) / abs(open) < Self.minimumRange {
            let half = abs(open) * Self.floorHalfRange
            lower = open - half
            upper = open + half
        } else {
            lower = low
            upper = high
        }
    }

    /// Maps a value to a y coordinate, clamped to the rect — under the scale
    /// floor a point can sit just outside the forced window.
    func y(for value: Double, in rect: CGRect) -> CGFloat {
        let span = upper - lower
        guard span > 0 else { return rect.midY }

        let ratio = min(max((value - lower) / span, 0), 1)
        return rect.height - CGFloat(ratio) * rect.height
    }
}

private struct SparklinePath: Shape {
    let values: [Double]
    let domain: SparklineDomain

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else {
            return Path { path in
                path.move(to: CGPoint(x: 0, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            }
        }

        let stepX = rect.width / CGFloat(values.count - 1)

        return Path { path in
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: CGFloat(index) * stepX, y: domain.y(for: value, in: rect))
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }
}

private struct SparklineReference: Shape {
    let domain: SparklineDomain

    func path(in rect: CGRect) -> Path {
        let y = domain.y(for: domain.open, in: rect)

        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
    }
}
