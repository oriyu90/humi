import Foundation

/// A named bundle of session defaults: shell, environment, working directory,
/// startup command, theme, scrollback, logging. A session created "from a profile"
/// carries its `id`; on (re)spawn the registry reads the profile for everything.
struct Profile: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    /// SF Symbol name for menus/launcher.
    var icon: String
    /// Index into `Hum.accents`.
    var colorIndex: Int

    var shellKind: ShellKind.RawKind
    var customShellPath: String
    var customShellArgs: String
    var useLoginArgs: Bool

    /// Extra environment variables (merged over the inherited environment).
    var env: [String: String]
    /// Command sent to the shell once, right after it starts.
    var startupCommand: String
    /// Working directory; `nil` = ask / home.
    var cwd: String?
    /// Theme family name; `nil` = follow the global theme.
    var themeName: String?
    var scrollback: Int?
    var loggingDefault: Bool

    static func decode(_ data: Data) -> Profile? { try? JSONDecoder().decode(Profile.self, from: data) }

    init(id: UUID = UUID(), name: String, icon: String = "terminal", colorIndex: Int = 0,
         shellKind: ShellKind = .login, customShellPath: String = "/bin/zsh",
         customShellArgs: String = "-l", useLoginArgs: Bool = true,
         env: [String: String] = [:], startupCommand: String = "", cwd: String? = nil,
         themeName: String? = nil, scrollback: Int? = nil, loggingDefault: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorIndex = colorIndex
        self.shellKind = shellKind.rawValue
        self.customShellPath = customShellPath
        self.customShellArgs = customShellArgs
        self.useLoginArgs = useLoginArgs
        self.env = env
        self.startupCommand = startupCommand
        self.cwd = cwd
        self.themeName = themeName
        self.scrollback = scrollback
        self.loggingDefault = loggingDefault
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Profile"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "terminal"
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        shellKind = try c.decodeIfPresent(String.self, forKey: .shellKind) ?? ShellKind.login.rawValue
        customShellPath = try c.decodeIfPresent(String.self, forKey: .customShellPath) ?? "/bin/zsh"
        customShellArgs = try c.decodeIfPresent(String.self, forKey: .customShellArgs) ?? "-l"
        useLoginArgs = try c.decodeIfPresent(Bool.self, forKey: .useLoginArgs) ?? true
        env = try c.decodeIfPresent([String: String].self, forKey: .env) ?? [:]
        startupCommand = try c.decodeIfPresent(String.self, forKey: .startupCommand) ?? ""
        cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        themeName = try c.decodeIfPresent(String.self, forKey: .themeName)
        scrollback = try c.decodeIfPresent(Int.self, forKey: .scrollback)
        loggingDefault = try c.decodeIfPresent(Bool.self, forKey: .loggingDefault) ?? false
    }

    var shellConfig: ShellConfig {
        ShellConfig(kind: ShellKind(rawValue: shellKind) ?? .login,
                    customPath: customShellPath, customArgs: customShellArgs, useLoginArgs: useLoginArgs)
    }
}

extension ShellKind { typealias RawKind = String }
