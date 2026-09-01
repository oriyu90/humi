import SwiftUI
import AppKit

/// A flipped container so y = 0 is the top (natural for scroll-fraction math).
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Shared scroll-position bridging for the notes sidebar. Both the editor and the
/// preview write a normalised 0…1 `fraction` as the user scrolls and restore it once
/// when they first appear — so toggling Edit⇄Preview keeps you roughly where you were.
/// The fraction is reset to 0 by the sidebar when the active note changes.
fileprivate final class ScrollSync: NSObject {
    let fraction: Binding<CGFloat>
    weak var scroll: NSScrollView?
    private var didRestore = false
    private var applying = false

    init(_ fraction: Binding<CGFloat>) { self.fraction = fraction }

    func attach(_ scroll: NSScrollView) {
        self.scroll = scroll
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(boundsChanged),
            name: NSView.boundsDidChangeNotification, object: scroll.contentView)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func boundsChanged() {
        guard didRestore, !applying, let scroll else { return }
        let f = Self.fraction(of: scroll)
        if abs(f - fraction.wrappedValue) > 0.0005 {
            DispatchQueue.main.async { self.fraction.wrappedValue = f }
        }
    }

    /// Call from `updateNSView`; restores the fraction exactly once, after layout.
    func restoreIfNeeded() {
        guard !didRestore, let scroll else { return }
        didRestore = true
        applying = true
        let target = fraction.wrappedValue
        DispatchQueue.main.async {
            scroll.layoutSubtreeIfNeeded()
            Self.scroll(scroll, toFraction: target)
            DispatchQueue.main.async { self.applying = false }
        }
    }

    static func fraction(of scroll: NSScrollView) -> CGFloat {
        let doc = scroll.documentView?.bounds.height ?? 0
        let vis = scroll.contentView.bounds.height
        let span = max(1, doc - vis)
        return min(1, max(0, scroll.contentView.bounds.origin.y / span))
    }

    static func scroll(_ scroll: NSScrollView, toFraction f: CGFloat) {
        let doc = scroll.documentView?.bounds.height ?? 0
        let vis = scroll.contentView.bounds.height
        let span = max(0, doc - vis)
        let y = min(span, max(0, f * span))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

// MARK: - Editor

/// Plain-text Markdown editor backed by `NSTextView`, with scroll-fraction bridging.
struct NotesEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var scrollFraction: CGFloat
    var font: NSFont
    var textColor: NSColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.drawsBackground = false
        tv.font = font
        tv.textColor = textColor
        tv.insertionPointColor = textColor
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.string = text

        context.coordinator.sync = ScrollSync($scrollFraction)
        context.coordinator.sync?.attach(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        // Always point the coordinator at the current binding — otherwise a reused
        // editor writes edits into whichever note it was first created for.
        context.coordinator.parent = self
        if let tv = scroll.documentView as? NSTextView {
            if tv.string != text {
                let sel = tv.selectedRange()
                tv.string = text
                tv.setSelectedRange(NSRange(location: min(sel.location, (text as NSString).length), length: 0))
            }
            if tv.font != font { tv.font = font }
            if tv.textColor != textColor {
                tv.textColor = textColor
                tv.insertionPointColor = textColor
            }
        }
        context.coordinator.sync?.restoreIfNeeded()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotesEditor
        fileprivate var sync: ScrollSync?
        init(_ parent: NotesEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let s = tv.string
            let current = parent               // snapshot: parent (hence its binding) is refreshed in updateNSView
            DispatchQueue.main.async { current.text = s }
        }
    }
}

// MARK: - Preview

/// Hosts arbitrary SwiftUI `content` in an `NSScrollView` with scroll-fraction bridging.
struct TrackingScroll<Content: View>: NSViewRepresentable {
    @Binding var scrollFraction: CGFloat
    @ViewBuilder var content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(host)
        scroll.documentView = doc
        context.coordinator.host = host

        NSLayoutConstraint.activate([
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            host.topAnchor.constraint(equalTo: doc.topAnchor),
            host.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])

        context.coordinator.sync = ScrollSync($scrollFraction)
        context.coordinator.sync?.attach(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.host?.rootView = content
        context.coordinator.sync?.restoreIfNeeded()
    }

    final class Coordinator {
        fileprivate var sync: ScrollSync?
        var host: NSHostingView<Content>?
    }
}
