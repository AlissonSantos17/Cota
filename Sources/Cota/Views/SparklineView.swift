import CotaKit
import SwiftUI

/// The small trend line of a closed panel row.
struct SparklineView: View {
    let data: [Decimal]
    let color: Color

    var body: some View {
        if let domain = SparklineDomain(values: values) {
            ZStack {
                SparklineReference(domain: domain)
                    .stroke(CotaTheme.moss, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                SparklinePath(values: values, domain: domain)
                    .stroke(
                        color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: CotaTheme.Size.sparkline.width, height: CotaTheme.Size.sparkline.height)
            .accessibilityLabel(L10n.t("a11y.trend"))
            .accessibilityValue(SparklineDomain.trendDescription(data))
        }
    }

    private var values: [Double] {
        data.map { NSDecimalNumber(decimal: $0).doubleValue }
    }
}

/// The large chart of an expanded panel row: the area under the line in the
/// trend's tint, the opening value dashed, the latest value marked with a
/// dot, and — when the pair has an alert on — the threshold as a dotted mint
/// line with its label.
struct PriceChartView: View {
    let data: [Decimal]
    let color: Color
    let fill: Color
    let alert: PriceAlert?

    var body: some View {
        if let domain {
            ZStack(alignment: .topLeading) {
                SparklineArea(values: values, domain: domain)
                    .fill(fill)

                SparklineReference(domain: domain)
                    .stroke(CotaTheme.moss, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                if let alert {
                    SparklineLevel(value: double(alert.threshold), domain: domain)
                        .stroke(
                            CotaTheme.mint.opacity(0.8),
                            style: StrokeStyle(lineWidth: 1, dash: [1, 3])
                        )
                }

                SparklinePath(values: values, domain: domain)
                    .stroke(
                        color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                SparklineEndDot(values: values, domain: domain)
                    .fill(Color.white)

                if let alert {
                    alertLabel(alert, domain: domain)
                }
            }
            .frame(width: CotaTheme.Size.chart.width, height: CotaTheme.Size.chart.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("a11y.trend"))
            .accessibilityValue(SparklineDomain.trendDescription(data))
        } else {
            Color.clear
                .frame(width: CotaTheme.Size.chart.width, height: CotaTheme.Size.chart.height)
        }
    }

    /// The threshold widens the scale, so the line is always on the chart
    /// however far the price is from it.
    private var domain: SparklineDomain? {
        SparklineDomain(values: values, including: alert.map { double($0.threshold) })
    }

    private var values: [Double] {
        data.map(double)
    }

    private func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func alertLabel(_ alert: PriceAlert, domain: SparklineDomain) -> some View {
        let rect = CGRect(origin: .zero, size: CotaTheme.Size.chart)
        let y = domain.y(for: double(alert.threshold), in: rect)
        let key = alert.isAbove ? "panel.alert.above" : "panel.alert.below"

        return HStack(spacing: 4) {
            Image(systemName: "bell")
                .font(.system(size: 9, weight: .semibold))
            Text(L10n.t(key, QuoteFormat.threshold(alert.threshold)))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(CotaTheme.onMint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(CotaTheme.mint, in: RoundedRectangle(cornerRadius: CotaTheme.Radius.segment))
        .offset(y: max(0, y - 9))
    }
}

/// Vertical scale for a sparkline, anchored to the opening value of the period.
///
/// Auto-scaling every series to its own min/max makes a pair that moved 0.02%
/// look as agitated as one that moved 0.5%. When the whole series fits inside
/// `minimumRange`, the scale falls back to a fixed window around the opening
/// value, so a flat series reads as flat.
struct SparklineDomain {
    private(set) var lower: Double
    private(set) var upper: Double
    let open: Double

    private static let minimumRange = 0.005
    private static let floorHalfRange = 0.0025

    init?(values: [Double], including extra: Double? = nil) {
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

        if let extra {
            // A little room past the threshold, so its label is not pressed
            // against the edge of the chart.
            let pad = (max(upper, extra) - min(lower, extra)) * 0.08
            if extra > upper { upper = extra + pad }
            if extra < lower { lower = extra - pad }
        }
    }

    static func trendDescription(_ data: [Decimal]) -> String {
        guard let first = data.first, let last = data.last else { return L10n.t("a11y.noData") }
        if last > first { return L10n.t("a11y.trendUp") }
        if last < first { return L10n.t("a11y.trendDown") }
        return L10n.t("a11y.trendFlat")
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

/// A horizontal line at an arbitrary value: the alert threshold.
private struct SparklineLevel: Shape {
    let value: Double
    let domain: SparklineDomain

    func path(in rect: CGRect) -> Path {
        let y = domain.y(for: value, in: rect)

        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
    }
}

/// The line closed down to the bottom edge, for the tinted area under it.
private struct SparklineArea: Shape {
    let values: [Double]
    let domain: SparklineDomain

    func path(in rect: CGRect) -> Path {
        var path = SparklinePath(values: values, domain: domain).path(in: rect)
        guard values.count >= 2 else { return path }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// The dot on the latest value.
private struct SparklineEndDot: Shape {
    let values: [Double]
    let domain: SparklineDomain

    func path(in rect: CGRect) -> Path {
        guard let last = values.last else { return Path() }
        let center = CGPoint(x: rect.width, y: domain.y(for: last, in: rect))
        return Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
    }
}
