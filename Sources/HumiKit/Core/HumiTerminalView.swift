import AppKit
import SwiftTerm

/// `LocalProcessTerminalView` with a few hooks SwiftTerm doesn't forward to the
/// process delegate: ⌘-clicked links, selection changes (for copy-on-select), and
/// clipboard-copy (OSC 52).
final class HumiTerminalView: LocalProcessTerminalView {

    var onOpenLink: ((String) -> Void)?
    var onSelectionChanged: ((String?) -> Void)?
    /// Fires when the user clicks or types in this terminal — used to remember
    /// "the terminal you're working in" for search / menu actions.
    var onInteracted: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onInteracted?()
        super.mouseDown(with: event)
    }

    override func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        onOpenLink?(link)
    }

    override func selectionChanged(source: SwiftTerm.Terminal) {
        super.selectionChanged(source: source)
        onSelectionChanged?(selectionActive ? getSelection() : nil)
    }
}
