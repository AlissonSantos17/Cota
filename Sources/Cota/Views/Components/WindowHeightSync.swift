import AppKit
import SwiftUI

extension View {
    /// Keeps the hosting window as tall as this view, anchored at the top.
    ///
    /// A `MenuBarExtra` window takes its size when it opens and keeps it:
    /// a panel row opening in place spilled past the bottom edge and was
    /// clipped. Measuring the content and resizing the window by hand makes
    /// the panel grow and shrink with it.
    func syncsWindowHeight() -> some View {
        modifier(WindowHeightSync())
    }
}

private struct WindowHeightSync: ViewModifier {
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { height = $0 }
            .background(WindowResizer(height: height))
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WindowResizer: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        let height = height
        // After the current layout pass: resizing the window from inside it
        // makes AppKit lay the hosting view out again, re-entrantly.
        DispatchQueue.main.async {
            guard height > 0, let window = view.window else { return }

            let current = window.contentRect(forFrameRect: window.frame)
            guard abs(current.height - height) > 0.5 else { return }

            var content = current
            content.size.height = height
            content.origin.y = current.maxY - height
            window.setFrame(window.frameRect(forContentRect: content), display: true)
        }
    }
}
