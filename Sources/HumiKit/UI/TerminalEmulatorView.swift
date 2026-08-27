import SwiftUI
import SwiftTerm

/// Bridges a session's `LocalProcessTerminalView` (held by `TerminalRegistry`) into SwiftUI.
/// The NSView is never created here — only looked up — so a view rebuild can't spawn a
/// second shell. The container re-hosts the (shared) terminal view defensively, so it
/// survives SwiftUI recycling a tile in and out of view.
struct TerminalEmulatorView: NSViewRepresentable {
    let session: Session
    @ObservedObject var settings: AppSettings
    var onTitle: (String) -> Void
    var onDirectory: (String?) -> Void
    var onExit: (Int32?) -> Void

    func makeNSView(context: Context) -> ContainerView {
        let container = ContainerView()
        rehost(into: container)
        return container
    }

    func updateNSView(_ container: ContainerView, context: Context) {
        rehost(into: container)
    }

    private func rehost(into container: ContainerView) {
        // nil == this session was closed; don't resurrect it into a new shell.
        guard let controller = TerminalRegistry.shared.controller(for: session, settings: settings) else { return }
        controller.onTitle = onTitle
        controller.onDirectory = onDirectory
        controller.onExit = onExit
        container.host(controller.terminalView)
    }

    /// Plain flipped container that pins the terminal to its bounds via frame layout
    /// (no Auto Layout — constraints to a previous recycled parent were causing 0-size views).
    final class ContainerView: NSView {
        private weak var hosted: NSView?

        override var isFlipped: Bool { true }

        func host(_ view: NSView) {
            guard hosted !== view else {
                view.frame = bounds
                return
            }
            hosted?.removeFromSuperview()
            view.removeFromSuperview()
            view.translatesAutoresizingMaskIntoConstraints = true
            view.autoresizingMask = [.width, .height]
            view.frame = bounds
            addSubview(view)
            hosted = view
        }

        override func layout() {
            super.layout()
            hosted?.frame = bounds
        }
    }
}
