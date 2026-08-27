import AppKit
import SwiftTerm

/// Owns exactly one `LocalProcessTerminalView` and its child shell for a session.
/// This is the *only* strong reference to the terminal NSView — SwiftUI never holds it,
/// so re-renders can't recreate PTYs. Lives in `TerminalRegistry`, keyed by session id.
@MainActor
final class TerminalController: NSObject, LocalProcessTerminalViewDelegate {

    let sessionID: UUID
    let terminalView: LocalProcessTerminalView
    private(set) var started = false
    private(set) var exited = false

    /// Callbacks into the SwiftUI world. Held weakly at the call site (store is @Published).
    var onTitle: ((String) -> Void)?
    var onDirectory: ((String?) -> Void)?
    var onExit: ((Int32?) -> Void)?

    init(sessionID: UUID, fontSize: CGFloat, scrollback: Int) {
        self.sessionID = sessionID
        let options = TerminalOptions(scrollback: max(0, scrollback))
        self.terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 400),
                                                     font: TerminalController.monoFont(fontSize),
                                                     options: options)
        super.init()
        terminalView.processDelegate = self   // weak on SwiftTerm's side
        applyTheme()
    }

    /// Bundled JetBrains Mono, falling back to the system monospaced face.
    static func monoFont(_ size: CGFloat) -> NSFont {
        NSFont(name: "JetBrains Mono", size: size)
            ?? NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func startIfNeeded(invocation: ShellInvocation, environment: [String], workingDirectory: String?) {
        guard !started else { return }
        started = true
        terminalView.startProcess(executable: invocation.executable,
                                  args: invocation.args,
                                  environment: environment,
                                  execName: invocation.execName,
                                  currentDirectory: workingDirectory)
    }

    func setFontSize(_ size: CGFloat) {
        terminalView.font = TerminalController.monoFont(size)
    }

    /// ⌘K — drop the scrollback history, then send Ctrl-L so the shell (readline/zsh
    /// line editor, or a full-screen program) repaints a clean screen with the current
    /// prompt intact. Matches Terminal.app's "画面を消去".
    func clearBuffer() {
        guard !exited else { return }
        terminalView.clearScrollback()
        terminalView.send(txt: "\u{0C}")   // form feed / Ctrl-L
    }

    /// SIGTERM + pty close (via SwiftTerm), then a SIGKILL backstop so a shell that
    /// ignores SIGTERM can't linger as an orphan. Used when a single tile is closed —
    /// the reap is deferred so the UI stays responsive.
    func terminate() {
        guard !exited else { return }
        exited = true
        let pid = terminalView.process.shellPid
        terminalView.processDelegate = nil
        terminalView.terminate()
        onTitle = nil; onDirectory = nil; onExit = nil
        guard pid > 0 else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            var status: Int32 = 0
            // Reap first: if it already exited, this clears the zombie.
            if waitpid(pid, &status, WNOHANG) == 0 {
                // Still alive — escalate, then reap.
                kill(pid, SIGKILL)
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    var s: Int32 = 0
                    _ = waitpid(pid, &s, WNOHANG)
                }
            }
        }
    }

    /// Blocking teardown for the app-quit path. `applicationWillTerminate` returns and
    /// the process exits immediately, so the deferred reap in `terminate()` would never
    /// run — a shell that ignores SIGTERM would be re-parented to launchd and linger.
    /// Here we SIGTERM, poll briefly, then SIGKILL + reap, all before returning.
    /// Bounded by `grace + 0.3s` per session.
    func terminateSync(grace: TimeInterval = 0.4) {
        guard !exited else { return }
        exited = true
        let pid = terminalView.process.shellPid
        terminalView.processDelegate = nil
        terminalView.terminate()          // sends SIGTERM, closes the pty
        onTitle = nil; onDirectory = nil; onExit = nil
        guard pid > 0 else { return }

        var status: Int32 = 0
        let deadline = Date().addingTimeInterval(grace)
        while Date() < deadline {
            if waitpid(pid, &status, WNOHANG) != 0 { return }   // exited & reaped
            usleep(20_000)                                       // 20 ms
        }
        // Still alive after the grace period — force it.
        kill(pid, SIGKILL)
        let hardDeadline = Date().addingTimeInterval(0.3)
        while Date() < hardDeadline {
            if waitpid(pid, &status, WNOHANG) != 0 { return }
            usleep(20_000)
        }
    }

    // MARK: Theme — cream paper, ink text. Default ANSI palette reads fine on cream.

    private func applyTheme() {
        terminalView.nativeBackgroundColor = NSColor(hex: 0xF7F4EC)
        terminalView.nativeForegroundColor = NSColor(hex: 0x1B1D22)
        terminalView.caretColor = NSColor(hex: 0xCBAE2E)
        terminalView.selectedTextBackgroundColor = NSColor(hex: 0x4FB7E8).withAlphaComponent(0.35)
    }

    // MARK: LocalProcessTerminalViewDelegate

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let value = title
        Task { @MainActor in self.onTitle?(value) }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        let value = directory
        Task { @MainActor in self.onDirectory?(value) }
    }

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        let code = exitCode
        Task { @MainActor in
            self.exited = true
            self.onExit?(code)
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
