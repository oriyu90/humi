import AppKit

/// Process-wide cache of live `TerminalController`s, keyed by session id.
/// SwiftUI views look controllers up here instead of creating them, so a view
/// rebuild never spawns a second shell for the same session.
@MainActor
public final class TerminalRegistry {
    public static let shared = TerminalRegistry()
    private init() {}

    private var controllers: [UUID: TerminalController] = [:]
    /// Sessions that have been closed, with the time they were closed. A late
    /// `updateNSView` for a disappearing tile must NOT resurrect these into a fresh
    /// shell — but the window is only ~one animation long, so entries are pruned
    /// aggressively to keep this bounded over a long-running app.
    private var reaped: [UUID: Date] = [:]
    private let reapedTTL: TimeInterval = 120

    private func pruneReaped() {
        guard reaped.count > 32 else { return }
        let cutoff = Date().addingTimeInterval(-reapedTTL)
        reaped = reaped.filter { $0.value > cutoff }
    }

    func controller(for session: Session,
                    settings: AppSettings,
                    makeStart: Bool = true) -> TerminalController? {
        if reaped[session.id] != nil { return nil }
        if let existing = controllers[session.id] { return existing }

        let profile = ProfileStore.shared.profile(session.profileID)
        let theme = profile?.themeName.flatMap { ThemeStore.shared.theme(named: $0) }
            ?? ThemeStore.shared.resolvedTheme
        let scrollback = profile?.scrollback ?? settings.effectiveScrollback

        let controller = TerminalController(sessionID: session.id,
                                            theme: theme,
                                            fontSize: CGFloat(settings.fontSize),
                                            scrollback: scrollback)
        controllers[session.id] = controller

        controller.applyTerminalPrefs(optionAsMeta: settings.optionAsMeta,
                                      mouseReporting: settings.mouseReporting,
                                      scrollSensitivity: CGFloat(settings.scrollSensitivity),
                                      scrollbar: settings.scrollbarStyle,
                                      bell: settings.bellStyle)

        if makeStart {
            var invocation = ShellResolver.resolve(config: profile?.shellConfig ?? settings.shellConfig)
            let env = ShellResolver.childEnvironment(extra: profile?.env ?? [:])
            // nil workingDirectory == "open as-is" → start in the user's home, not
            // Humi's launch cwd ("/" when opened from Finder). A folder that has since
            // been deleted also falls back to home.
            let cwd = ShellResolver.startDirectory(requested: session.workingDirectory ?? profile?.cwd)

            if session.logging,
               let path = SessionLogger.logPath(sessionTitle: session.title,
                                                dir: settings.logDirectory,
                                                pattern: settings.logFilenamePattern) {
                invocation = SessionLogger.wrap(invocation, logPath: path)
            }
            let shellKind = profile?.shellConfig.kind ?? settings.shellConfig.kind
            controller.startIfNeeded(invocation: invocation,
                                     environment: env,
                                     workingDirectory: cwd,
                                     startupCommand: profile?.startupCommand ?? "",
                                     osc7Snippet: session.logging ? nil : ShellResolver.osc7Snippet(for: shellKind))
        }
        return controller
    }

    func existing(_ id: UUID) -> TerminalController? { controllers[id] }

    /// Drop the (exited) controller so the next view update recreates it with a fresh shell.
    func restart(session: Session, settings: AppSettings) {
        controllers[session.id]?.terminate()
        controllers.removeValue(forKey: session.id)
        // not added to `reaped` — the session is still open, only its process ended
        _ = controller(for: session, settings: settings)
    }

    func terminate(_ id: UUID) {
        reaped[id] = Date()
        pruneReaped()
        controllers[id]?.terminate()
        controllers.removeValue(forKey: id)
    }

    public func terminateAll() {
        for (id, c) in controllers { reaped[id] = Date(); c.terminate() }
        controllers.removeAll()
        pruneReaped()
    }

    /// Blocking teardown for `applicationWillTerminate` — every child shell is
    /// SIGTERM'd, polled, then SIGKILL'd and reaped before this returns.
    public func terminateAllSync() {
        for (_, c) in controllers { c.terminateSync() }
        controllers.removeAll()
        reaped.removeAll()
    }

    public func setFontSize(_ size: CGFloat) {
        for (_, c) in controllers { c.setFontSize(size) }
    }

    /// Re-apply the currently resolved theme (+ font size) to every live terminal.
    public func applyTheme() {
        let theme = ThemeStore.shared.resolvedTheme
        let size = CGFloat(AppSettings.shared.fontSize)
        for (_, c) in controllers { c.applyTheme(theme, fontSize: size) }
    }

    /// Re-apply terminal-behaviour prefs to every live terminal.
    public func applyTerminalPrefs() {
        let s = AppSettings.shared
        for (_, c) in controllers {
            c.applyTerminalPrefs(optionAsMeta: s.optionAsMeta,
                                 mouseReporting: s.mouseReporting,
                                 scrollSensitivity: CGFloat(s.scrollSensitivity),
                                 scrollbar: s.scrollbarStyle,
                                 bell: s.bellStyle)
        }
    }

    /// Last terminal that became first responder — so actions driven from the search
    /// bar / a menu still target "the terminal you were just in".
    private(set) var lastFocusedID: UUID?
    func noteFocused(_ id: UUID) { lastFocusedID = id }

    /// The controller the user is working in: the live first-responder terminal, else
    /// the last one that had focus, else the only one, else nil.
    func focusedController() -> TerminalController? {
        for c in controllers.values {
            guard let window = c.terminalView.window, window.isKeyWindow,
                  let responder = window.firstResponder as? NSView else { continue }
            if responder === c.terminalView || responder.isDescendant(of: c.terminalView) {
                return c
            }
        }
        if let id = lastFocusedID, let c = controllers[id] { return c }
        return controllers.count == 1 ? controllers.values.first : nil
    }

    /// ⌘K — clear the scrollback of the focused (or last-focused) session's terminal.
    public func clearFocused() {
        if let c = focusedController() { c.clearBuffer() } else { NSSound.beep() }
    }
}
