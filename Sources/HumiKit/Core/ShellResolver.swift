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

    /// Map a shell executable basename to the dialect its OSC 7 snippet needs.
    static func osc7Kind(forShellBasename name: String) -> ShellKind {
        switch name {
        case "fish": return .fish
        case "bash": return .bash
        default:     return .zsh
        }
    }

    /// Which shell dialect the OSC 7 snippet should target. For `.login` the `kind` says
    /// nothing about the actual shell, so resolve it — otherwise a fish login shell gets
    /// the zsh snippet fed to it and errors on `autoload` / `add-zsh-hook`.
    static func effectiveKindForOSC7(config: ShellConfig,
                                     environment: [String: String] = ProcessInfo.processInfo.environment) -> ShellKind {
        guard config.kind == .login else { return config.kind }
        let path = loginShellPath(environment: environment)
        return osc7Kind(forShellBasename: (path as NSString).lastPathComponent)
    }

    /// A one-liner that makes the shell report its working directory (OSC 7) on every
    /// prompt, so Humi's title / status bar / git panel follow `cd`. Stock macOS zsh
    /// only emits OSC 7 for Terminal.app, so Humi injects this itself.
    static func osc7Snippet(for kind: ShellKind) -> String? {
        switch kind {
        case .zsh, .login:
            return #"autoload -Uz add-zsh-hook 2>/dev/null; __humi_osc7(){ printf '\033]7;file://%s%s\033\\' "${HOST:-localhost}" "$PWD" }; add-zsh-hook precmd __humi_osc7 2>/dev/null || precmd_functions+=(__humi_osc7)"#
        case .bash:
            return #"__humi_osc7(){ printf '\033]7;file://%s%s\033\\' "${HOSTNAME:-localhost}" "$PWD"; }; case "$PROMPT_COMMAND" in *__humi_osc7*) ;; *) PROMPT_COMMAND="__humi_osc7${PROMPT_COMMAND:+; $PROMPT_COMMAND}";; esac"#
        case .fish:
            return #"function __humi_osc7 --on-event fish_prompt; printf '\033]7;file://%s%s\033\\' (hostname) "$PWD"; end"#
        case .custom:
            return nil
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
