import Foundation

/// Resolves the executable + argv + argv0 for a new shell, from settings.
/// Pure and synchronous so it is trivially unit-testable.
struct ShellInvocation: Equatable {
    var executable: String
    var args: [String]
    /// argv[0] — a leading "-" makes it a login shell (what Terminal.app does).
    var execName: String
}

/// Plain snapshot of the shell-related settings, so `ShellResolver` stays pure and testable.
struct ShellConfig: Equatable {
    var kind: ShellKind
    var customPath: String
    var customArgs: String
    var useLoginArgs: Bool
}

enum ShellResolver {

    /// The login shell for the current user: getpwuid → $SHELL → /bin/zsh.
    static func loginShellPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell {
            let path = String(cString: shell)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        if let envShell = environment["SHELL"], FileManager.default.isExecutableFile(atPath: envShell) {
            return envShell
        }
        return "/bin/zsh"
    }

    private static let knownPaths: [String: [String]] = [
        "zsh":  ["/bin/zsh", "/usr/local/bin/zsh", "/opt/homebrew/bin/zsh"],
        "bash": ["/bin/bash", "/usr/local/bin/bash", "/opt/homebrew/bin/bash"],
        "fish": ["/usr/local/bin/fish", "/opt/homebrew/bin/fish", "/usr/bin/fish"],
    ]

    static func firstExecutable(_ candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func resolve(config: ShellConfig,
                        environment: [String: String] = ProcessInfo.processInfo.environment) -> ShellInvocation {
        switch config.kind {
        case .login:
            // argv0 with a leading "-" makes it a login shell (Terminal.app's convention).
            let path = loginShellPath(environment: environment)
            let name = "-" + (path as NSString).lastPathComponent
            return ShellInvocation(executable: path, args: [], execName: name)
        case .zsh, .bash, .fish:
            let path = firstExecutable(knownPaths[config.kind.rawValue] ?? []) ?? loginShellPath(environment: environment)
            return ShellInvocation(executable: path,
                                   args: config.useLoginArgs ? ["-l"] : [],
                                   execName: (path as NSString).lastPathComponent)
        case .custom:
            let path = config.customPath.isEmpty ? loginShellPath(environment: environment) : config.customPath
            let args = config.customArgs.split(separator: " ").map(String.init)
            return ShellInvocation(executable: path,
                                   args: args,
                                   execName: (path as NSString).lastPathComponent)
        }
    }

    /// The directory a new shell should start in. Returns `requested` only if it still
    /// exists and is a directory; otherwise the user's home. A restored session whose
    /// folder was deleted must not fail to launch or land in "/".
    static func startDirectory(requested: String?,
                               home: String = NSHomeDirectory(),
                               fileManager: FileManager = .default) -> String {
        guard let requested, !requested.isEmpty else { return home }
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: requested, isDirectory: &isDir), isDir.boolValue {
            return requested
        }
        return home
    }

    /// Environment for the child: inherit, then make sure a sane TERM / LANG / COLORTERM
    /// are present, then apply any profile overrides (`extra`).
    static func childEnvironment(base: [String: String] = ProcessInfo.processInfo.environment,
                                 extra: [String: String] = [:]) -> [String] {
        var env = base
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        env["TERM_PROGRAM"] = "Humi"
        env.removeValue(forKey: "TERM_PROGRAM_VERSION")
        for (k, v) in extra where !k.isEmpty { env[k] = v }
        return env.map { "\($0.key)=\($0.value)" }
    }
}
