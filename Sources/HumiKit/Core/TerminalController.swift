import AppKit
import SwiftTerm

/// Owns exactly one `LocalProcessTerminalView` and its child shell for a session.
/// This is the *only* strong reference to the terminal NSView — SwiftUI never holds it,
/// so re-renders can't recreate PTYs. Lives in `TerminalRegistry`, keyed by session id.
@MainActor
final class TerminalController: NSObject, LocalProcessTerminalViewDelegate {

    let sessionID: UUID
    let terminalView: HumiTerminalView
    /// Directory the shell started in — used for classifying relative paths on ⌘-click.
    var currentDirectory: String?
    private(set) var started = false
    private(set) var exited = false

    /// Callbacks into the SwiftUI world. Held weakly at the call site (store is @Published).
    var onTitle: ((String) -> Void)?
    var onDirectory: ((String?) -> Void)?
    var onExit: ((Int32?) -> Void)?

    private var theme: Theme
    private var fontSize: CGFloat

    init(sessionID: UUID, theme: Theme, fontSize: CGFloat, scrollback: Int) {
        self.sessionID = sessionID
        self.theme = theme
        self.fontSize = fontSize
        let options = TerminalOptions(scrollback: max(0, scrollback))
        self.terminalView = HumiTerminalView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 400),
            font: FontResolver.terminalFont(family: theme.fontFamily, size: fontSize, cjkFamily: theme.cjkFontFamily),
            options: options)
        super.init()
        terminalView.processDelegate = self   // weak on SwiftTerm's side
        terminalView.onOpenLink = { [weak self] link in
            guard let self else { return }
            PathActioner.open(link, cwd: self.currentDirectory,
                              editorCommand: AppSettings.shared.editorCommand)
        }
        terminalView.onSelectionChanged = { text in
            guard AppSettings.shared.copyOnSelect, let text, !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        terminalView.onInteracted = { [weak self] in
            guard let self else { return }
            TerminalRegistry.shared.noteFocused(self.sessionID)
        }
        applyTheme(theme, fontSize: fontSize)
    }

    static func monoFont(_ size: CGFloat) -> NSFont { FontResolver.fallbackMono(size) }

    /// Terminal behaviour prefs that can change while a session is live.
    func applyTerminalPrefs(optionAsMeta: Bool, mouseReporting: Bool,
                            scrollSensitivity: CGFloat, scrollbar: ScrollbarStyle,
                            bell: BellStyle) {
        terminalView.optionAsMetaKey = optionAsMeta
        terminalView.allowMouseReporting = mouseReporting
        terminalView.scrollSensitivity = scrollSensitivity
        terminalView.scrollerStyle = (scrollbar == .legacy) ? .legacy : .overlay
        switch bell {
        case .off:    terminalView.bellStyle = .none
        case .sound:  terminalView.bellStyle = .sound
        case .visual: terminalView.bellStyle = .visual
        case .notify: terminalView.bellStyle = .soundAndVisual   // notification handled in Phase 11
        }
    }

    func startIfNeeded(invocation: ShellInvocation, environment: [String],
                       workingDirectory: String?, startupCommand: String = "") {
        guard !started else { return }
        started = true
        currentDirectory = workingDirectory
        terminalView.startProcess(executable: invocation.executable,
                                  args: invocation.args,
                                  environment: environment,
                                  execName: invocation.execName,
                                  currentDirectory: workingDirectory)
        let cmd = startupCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cmd.isEmpty {
            // The shell needs a beat to reach its first prompt.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, !self.exited else { return }
                self.terminalView.send(txt: cmd + "\n")
            }
        }
    }

    // MARK: Search (⌘F)

    @discardableResult
    func find(_ term: String, forward: Bool) -> Bool {
        guard !term.isEmpty else { return false }
        return forward ? terminalView.findNext(term) : terminalView.findPrevious(term)
    }

    /// `(matchIndex, total)` for the current term.
    func matchSummary(_ term: String) -> (index: Int, total: Int) {
        guard !term.isEmpty else { return (0, 0) }
        return terminalView.searchMatchSummary(term)
    }

    // MARK: Selection actions (context menu)

    var selectedText: String? { terminalView.selectionActive ? terminalView.getSelection() : nil }

    @discardableResult
    func openSelection() -> Bool {
        guard let text = selectedText else { return false }
        return PathActioner.open(text, cwd: currentDirectory, editorCommand: AppSettings.shared.editorCommand)
    }

    /// Heuristic "is something running in the foreground": the shell has a child process.
    var hasLiveForegroundChild: Bool {
        let pid = terminalView.process.shellPid
        guard pid > 0 else { return false }
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var len = 0
        guard sysctl(&name, 3, nil, &len, nil, 0) == 0, len > 0 else { return false }
        let count = len / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&name, 3, &procs, &len, nil, 0) == 0 else { return false }
        let actual = len / MemoryLayout<kinfo_proc>.stride
        for i in 0..<min(actual, procs.count) {
            if procs[i].kp_eproc.e_ppid == pid { return true }
        }
        return false
    }

    func setFontSize(_ size: CGFloat) {
        fontSize = size
        terminalView.font = FontResolver.terminalFont(
            family: theme.fontFamily, size: size, cjkFamily: theme.cjkFontFamily)
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

    // MARK: Theme

    func applyTheme(_ theme: Theme, fontSize: CGFloat) {
        self.theme = theme
        self.fontSize = fontSize
        terminalView.nativeBackgroundColor = theme.background.nsColor
        terminalView.nativeForegroundColor = theme.foreground.nsColor
        terminalView.caretColor = theme.cursor.nsColor
        terminalView.caretTextColor = theme.cursorText?.nsColor
        terminalView.selectedTextBackgroundColor = theme.selectionBackground.nsColor.withAlphaComponent(0.35)
        if let sf = theme.selectionForeground?.nsColor { terminalView.selectedTextForegroundColor = sf }
        terminalView.useBrightColors = theme.useBrightBold
        if theme.ansi.count == 16 {
            terminalView.installColors(theme.ansi.map(\.swiftTerm))
        }
        terminalView.getTerminal().setCursorStyle(theme.cursorSpec.swiftTerm)
        terminalView.font = FontResolver.terminalFont(
            family: theme.fontFamily, size: fontSize, cjkFamily: theme.cjkFontFamily)
    }

    // MARK: LocalProcessTerminalViewDelegate

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let value = title
        Task { @MainActor in self.onTitle?(value) }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        let value = directory
        Task { @MainActor in
            if let value { self.currentDirectory = value }
            self.onDirectory?(value)
        }
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
