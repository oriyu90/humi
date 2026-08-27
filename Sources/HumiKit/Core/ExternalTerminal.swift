import AppKit

/// Opens a folder in the user's configured external terminal app.
///
/// **Reserved for a future release.** v1.0 is embedded-only (per the product spec),
/// so nothing in the UI calls this yet. Kept in tree — with `ExternalTerminalApp` and
/// `AppSettings.externalTerminal` — so the v1.1 "open in iTerm / Terminal.app" option
/// can be wired back without rebuilding it. See `humi.md` § 今後の予定.
enum ExternalTerminal {

    static func isInstalled(_ app: ExternalTerminalApp) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) != nil
    }

    static func open(directory: String?, using app: ExternalTerminalApp) {
        let path = directory ?? NSHomeDirectory()
        switch app {
        case .terminal:
            runAppleScript("""
            tell application "Terminal"
                activate
                do script "cd \(shellQuote(path)) && clear"
            end tell
            """)
        case .iterm:
            runAppleScript("""
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window to create tab with default profile
                end if
                tell current session of current window to write text "cd \(shellQuote(path)) && clear"
            end tell
            """)
        }
    }

    // MARK: helpers

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runAppleScript(_ source: String) {
        // NSAppleScript must run on the main thread.
        let work = {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error { NSLog("Humi: external terminal AppleScript failed: \(error)") }
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
