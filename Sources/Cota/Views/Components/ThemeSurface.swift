import AppKit
import SwiftUI

/// The background of a themed surface: a flat fill, or — on Liquid Glass —
/// the system material with the palette's tint over it.
///
/// macOS 26 gets the real Liquid Glass (`glassEffect`). Earlier systems get
/// an `NSVisualEffectView` blurring what is behind the window, which is as
/// close as AppKit gets.
struct ThemeSurface<S: Shape>: View {
    let fill: Color
    let shape: S

    init(_ fill: Color, in shape: S) {
        self.fill = fill
        self.shape = shape
    }

    var body: some View {
        if CotaTheme.palette.isGlass {
            glass
        } else {
            shape.fill(fill)
        }
    }

    @ViewBuilder
    private var glass: some View {
        #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                shape.fill(fill.opacity(0.5)).glassEffect(.regular, in: shape)
            } else {
                legacyGlass
            }
        #else
            legacyGlass
        #endif
    }

    private var legacyGlass: some View {
        ZStack {
            VisualEffectBackground()
            fill
        }
        .clipShape(shape)
        .overlay(
            // The lit top edge that sells the glass.
            shape.stroke(
                LinearGradient(
                    colors: [.white.opacity(0.28), .white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
        )
    }
}

extension ThemeSurface where S == Rectangle {
    init(_ fill: Color) { self.init(fill, in: Rectangle()) }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
