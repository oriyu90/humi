import SwiftUI
import Foundation

enum ShellKind: String, CaseIterable, Identifiable {
    case login   // the user's login shell (getpwuid → $SHELL → /bin/zsh)
    case zsh
    case bash
    case fish
    case custom

    var id: String { rawValue }
    @MainActor var label: String {
        switch self {
        case .login:  return L("shell.login")
        case .zsh:    return "zsh"
        case .bash:   return "bash"
        case .fish:   return "fish"
        case .custom: return L("shell.custom")
        }
    }
}

enum ExternalTerminalApp: String, CaseIterable, Identifiable {
    case terminal
    case iterm

    var id: String { rawValue }
    @MainActor var label: String {
        switch self {
        case .terminal: return L("ext.terminal")
        case .iterm:    return L("ext.iterm")
        }
    }
    var bundleID: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm:    return "com.googlecode.iterm2"
        }
    }
}

/// User settings. Backed directly by `UserDefaults` with manual `objectWillChange`
/// notification — `@AppStorage` does NOT publish when used as a stored property on a
/// plain `ObservableObject`, so observing views would never refresh.
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    /// Called after `fontSize` changes so live terminals can re-render.
    public var onFontSizeChange: ((CGFloat) -> Void)?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.shellKind: ShellKind.login.rawValue,
            Keys.customShellPath: "/bin/zsh",
            Keys.customShellArgs: "-l",
            Keys.useLoginShellArgs: true,
            Keys.fontSize: 13.0,
            Keys.scrollbackLines: 10_000,
            Keys.externalTerminal: ExternalTerminalApp.terminal.rawValue,
            Keys.notesVisible: true,
            Keys.notesPreview: false,
            Keys.appLanguage: "system",
        ])
        Localization.shared.apply(appLanguage)
    }

    private enum Keys {
        static let shellKind = "shellKind"
        static let customShellPath = "customShellPath"
        static let customShellArgs = "customShellArgs"
        static let useLoginShellArgs = "loginShellArgs"
        static let fontSize = "fontSize"
        static let scrollbackLines = "scrollbackLines"
        static let externalTerminal = "externalTerminal"
        static let notesVisible = "notesVisible"
        static let notesPreview = "notesPreview"
        static let appLanguage = "humiAppLanguage"
    }

    private func set<T>(_ value: T, _ key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
    }

    /// SwiftUI binding for a settable property (the computed vars aren't `@Published`,
    /// so `$settings.foo` is unavailable — use `settings.bind(\.foo)`).
    func bind<T>(_ keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] }, set: { self[keyPath: keyPath] = $0 })
    }

    var shellKind: ShellKind {
        get { ShellKind(rawValue: defaults.string(forKey: Keys.shellKind) ?? "") ?? .login }
        set { set(newValue.rawValue, Keys.shellKind) }
    }
    var customShellPath: String {
        get { defaults.string(forKey: Keys.customShellPath) ?? "/bin/zsh" }
        set { set(newValue, Keys.customShellPath) }
    }
    var customShellArgs: String {
        get { defaults.string(forKey: Keys.customShellArgs) ?? "-l" }
        set { set(newValue, Keys.customShellArgs) }
    }
    var useLoginShellArgs: Bool {
        get { defaults.bool(forKey: Keys.useLoginShellArgs) }
        set { set(newValue, Keys.useLoginShellArgs) }
    }
    var fontSize: Double {
        get { defaults.double(forKey: Keys.fontSize) }
        set {
            let clamped = min(max(newValue, 9), 22)
            set(clamped, Keys.fontSize)
            onFontSizeChange?(CGFloat(clamped))
        }
    }
    var scrollbackLines: Int {
        get { max(200, defaults.integer(forKey: Keys.scrollbackLines)) }
        set { set(min(max(newValue, 1_000), 200_000), Keys.scrollbackLines) }
    }
    var notesVisible: Bool {
        get { defaults.bool(forKey: Keys.notesVisible) }
        set { set(newValue, Keys.notesVisible) }
    }
    var notesPreview: Bool {
        get { defaults.bool(forKey: Keys.notesPreview) }
        set { set(newValue, Keys.notesPreview) }
    }
    /// `"system"` or a code with an `.lproj` (`ja`, `en`, `zh-Hans`, `pt-BR`, `es`).
    var appLanguage: String {
        get { defaults.string(forKey: Keys.appLanguage) ?? "system" }
        set {
            set(newValue, Keys.appLanguage)
            Localization.shared.apply(newValue)
        }
    }
    var externalTerminal: ExternalTerminalApp {
        get { ExternalTerminalApp(rawValue: defaults.string(forKey: Keys.externalTerminal) ?? "") ?? .terminal }
        set { set(newValue.rawValue, Keys.externalTerminal) }
    }

    var shellConfig: ShellConfig {
        ShellConfig(kind: shellKind,
                    customPath: customShellPath,
                    customArgs: customShellArgs,
                    useLoginArgs: useLoginShellArgs)
    }
}
