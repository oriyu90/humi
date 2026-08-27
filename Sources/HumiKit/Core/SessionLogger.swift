import Foundation

/// Per-session output logging. Implemented by launching the shell under
/// `/usr/bin/script`, which mirrors the pty to a file — reliable and dependency-free.
enum SessionLogger {

    /// Resolve the log file path for a session, creating the directory if needed.
    static func logPath(sessionTitle: String, dir: String, pattern: String) -> String? {
        let base = (dir as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let safeName = sessionTitle.isEmpty ? "session"
            : sessionTitle.replacingOccurrences(of: "/", with: "-")
                          .replacingOccurrences(of: " ", with: "_")
        let file = pattern
            .replacingOccurrences(of: "{name}", with: safeName)
            .replacingOccurrences(of: "{date}", with: df.string(from: Date()))
        return (base as NSString).appendingPathComponent(file.isEmpty ? "\(safeName).log" : file)
    }

    /// Wrap a shell invocation so its session is appended to `logPath`.
    /// Note: `script` runs the shell as a plain command, so the login-shell argv0
    /// ("-zsh") convention is lost for logged sessions — acceptable.
    static func wrap(_ inv: ShellInvocation, logPath: String) -> ShellInvocation {
        ShellInvocation(
            executable: "/usr/bin/script",
            args: ["-q", "-a", logPath, inv.executable] + inv.args,
            execName: "script")
    }
}
