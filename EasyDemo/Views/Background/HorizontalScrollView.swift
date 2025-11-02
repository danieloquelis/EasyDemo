import SwiftUI
import AppKit

struct HorizontalScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = hostingView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
            hostingView.needsLayout = true
        }
    }
}
