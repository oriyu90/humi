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

enum ScrollbarStyle: String, CaseIterable, Identifiable, Sendable {
    case overlay, legacy
    var id: String { rawValue }
}

enum BellStyle: String, CaseIterable, Identifiable, Sendable {
    case off, sound, visual, notify
    var id: String { rawValue }
}

enum ConfirmClose: String, CaseIterable, Identifiable, Sendable {
    case never, busy, always
    var id: String { rawValue }
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
    /// Called after a terminal-behaviour pref changes (option-as-meta, mouse
    /// reporting, scroll sensitivity, scrollbar style) so live terminals re-apply.
    public var onTerminalPrefsChange: (() -> Void)?
    /// Called after the global hotkey pref changes so the Carbon registration is redone.
    public var onGlobalHotkeyChange: (() -> Void)?
    /// Called after a notification / output-trigger pref changes so live terminals
    /// re-evaluate whether they need an output watcher.
    public var onAlertPrefsChange: (() -> Void)?

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
            Keys.optionAsMeta: true,
            Keys.mouseReporting: true,
            Keys.scrollSensitivity: 1.0,
            Keys.scrollbarStyle: ScrollbarStyle.overlay.rawValue,
            Keys.copyOnSelect: false,
            Keys.confirmMultilinePaste: true,
            Keys.bellStyle: BellStyle.sound.rawValue,
            Keys.terminalMargin: 4.0,
            Keys.unlimitedScrollback: false,
            Keys.editorCommand: "code -g {file}:{line}",
            Keys.confirmClose: ConfirmClose.busy.rawValue,
            Keys.logDirectory: (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Humi Logs"),
            Keys.logFilenamePattern: "{name}-{date}.log",
            Keys.statusBarEnabled: false,
            Keys.statusCwd: true,
            Keys.statusShell: true,
            Keys.statusGit: true,
            Keys.statusClock: true,
            Keys.statusProcess: false,
            Keys.globalHotkeyEnabled: false,
            Keys.notifyProcessExit: false,
            Keys.notifyProcessExitThreshold: 30,
            Keys.notifyOnBell: false,
            Keys.notifyOnlyWhenInactive: true,
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
        static let optionAsMeta = "optionAsMeta"
        static let mouseReporting = "mouseReporting"
        static let scrollSensitivity = "scrollSensitivity"
        static let scrollbarStyle = "scrollbarStyle"
        static let copyOnSelect = "copyOnSelect"
        static let confirmMultilinePaste = "confirmMultilinePaste"
        static let bellStyle = "bellStyle"
        static let terminalMargin = "terminalMargin"
        static let unlimitedScrollback = "unlimitedScrollback"
        static let editorCommand = "editorCommand"
        static let confirmClose = "confirmClose"
        static let logDirectory = "logDirectory"
        static let logFilenamePattern = "logFilenamePattern"
        static let statusBarEnabled = "statusBarEnabled"
        static let statusCwd = "statusCwd"
        static let statusShell = "statusShell"
        static let statusGit = "statusGit"
        static let statusClock = "statusClock"
        static let statusProcess = "statusProcess"
        static let globalHotkeyEnabled = "globalHotkeyEnabled"
        static let globalHotkeyChord = "globalHotkeyChord"
        static let notifyProcessExit = "notifyProcessExit"
        static let notifyProcessExitThreshold = "notifyProcessExitThreshold"
        static let notifyOnBell = "notifyOnBell"
        static let notifyOnlyWhenInactive = "notifyOnlyWhenInactive"
        static let notifyWatchStrings = "notifyWatchStrings"
        static let triggers = "outputTriggers"
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

    // MARK: Terminal behaviour (v1.1)

    private func setTerminalPref<T>(_ value: T, _ key: String) { set(value, key); onTerminalPrefsChange?() }

    var optionAsMeta: Bool {
        get { defaults.bool(forKey: Keys.optionAsMeta) }
        set { setTerminalPref(newValue, Keys.optionAsMeta) }
    }
    var mouseReporting: Bool {
        get { defaults.bool(forKey: Keys.mouseReporting) }
        set { setTerminalPref(newValue, Keys.mouseReporting) }
    }
    var scrollSensitivity: Double {
        get { let v = defaults.double(forKey: Keys.scrollSensitivity); return v == 0 ? 1 : v }
        set { setTerminalPref(min(max(newValue, 0.2), 5), Keys.scrollSensitivity) }
    }
    var scrollbarStyle: ScrollbarStyle {
        get { ScrollbarStyle(rawValue: defaults.string(forKey: Keys.scrollbarStyle) ?? "") ?? .overlay }
        set { setTerminalPref(newValue.rawValue, Keys.scrollbarStyle) }
    }
    var copyOnSelect: Bool {
        get { defaults.bool(forKey: Keys.copyOnSelect) }
        set { setTerminalPref(newValue, Keys.copyOnSelect) }
    }
    var confirmMultilinePaste: Bool {
        get { defaults.bool(forKey: Keys.confirmMultilinePaste) }
        set { set(newValue, Keys.confirmMultilinePaste) }
    }
    var bellStyle: BellStyle {
        get { BellStyle(rawValue: defaults.string(forKey: Keys.bellStyle) ?? "") ?? .sound }
        set { setTerminalPref(newValue.rawValue, Keys.bellStyle) }
    }
    var terminalMargin: Double {
        get { max(0, defaults.double(forKey: Keys.terminalMargin)) }
        set { set(min(max(newValue, 0), 24), Keys.terminalMargin) }
    }
    var unlimitedScrollback: Bool {
        get { defaults.bool(forKey: Keys.unlimitedScrollback) }
        set { set(newValue, Keys.unlimitedScrollback) }
    }
    /// Effective scrollback for new sessions (`unlimited` → a very large number).
    var effectiveScrollback: Int { unlimitedScrollback ? 10_000_000 : scrollbackLines }
    var editorCommand: String {
        get { defaults.string(forKey: Keys.editorCommand) ?? "code -g {file}:{line}" }
        set { set(newValue, Keys.editorCommand) }
    }
    var confirmClose: ConfirmClose {
        get { ConfirmClose(rawValue: defaults.string(forKey: Keys.confirmClose) ?? "") ?? .busy }
        set { set(newValue.rawValue, Keys.confirmClose) }
    }
    var logDirectory: String {
        get { defaults.string(forKey: Keys.logDirectory) ?? (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Humi Logs") }
        set { set(newValue, Keys.logDirectory) }
    }
    var logFilenamePattern: String {
        get { defaults.string(forKey: Keys.logFilenamePattern) ?? "{name}-{date}.log" }
        set { set(newValue, Keys.logFilenamePattern) }
    }
    var statusBarEnabled: Bool { get { defaults.bool(forKey: Keys.statusBarEnabled) } set { set(newValue, Keys.statusBarEnabled) } }
    var statusCwd: Bool     { get { defaults.bool(forKey: Keys.statusCwd) }     set { set(newValue, Keys.statusCwd) } }
    var statusShell: Bool   { get { defaults.bool(forKey: Keys.statusShell) }   set { set(newValue, Keys.statusShell) } }
    var statusGit: Bool     { get { defaults.bool(forKey: Keys.statusGit) }     set { set(newValue, Keys.statusGit) } }
    var statusClock: Bool   { get { defaults.bool(forKey: Keys.statusClock) }   set { set(newValue, Keys.statusClock) } }
    var statusProcess: Bool { get { defaults.bool(forKey: Keys.statusProcess) } set { set(newValue, Keys.statusProcess) } }

    // MARK: v1.2 — global hotkey (Carbon; separate from keymap.json)

    var globalHotkeyEnabled: Bool {
        get { defaults.bool(forKey: Keys.globalHotkeyEnabled) }
        set { set(newValue, Keys.globalHotkeyEnabled); onGlobalHotkeyChange?() }
    }
    /// The chord that toggles the Humi window from anywhere. Stored as a JSON `KeyChord`
    /// string; defaults to ⌘⌥⌃T when unset.
    var globalHotkeyChord: KeyChord {
        get {
            guard let s = defaults.string(forKey: Keys.globalHotkeyChord),
                  let data = s.data(using: .utf8),
                  let chord = try? JSONDecoder().decode(KeyChord.self, from: data) else {
                return KeyChord(key: "t", modifiers: NSEvent.ModifierFlags([.command, .option, .control]).rawValue)
            }
            return chord
        }
        set {
            let s = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            set(s, Keys.globalHotkeyChord)
            onGlobalHotkeyChange?()
        }
    }

    // MARK: v1.2 — notifications + output triggers

    var notifyProcessExit: Bool {
        get { defaults.bool(forKey: Keys.notifyProcessExit) }
        set { set(newValue, Keys.notifyProcessExit); onAlertPrefsChange?() }
    }
    var notifyProcessExitThreshold: Int {
        get { max(1, defaults.integer(forKey: Keys.notifyProcessExitThreshold)) }
        set { set(min(max(newValue, 1), 3600), Keys.notifyProcessExitThreshold) }
    }
    var notifyOnBell: Bool {
        get { defaults.bool(forKey: Keys.notifyOnBell) }
        set { set(newValue, Keys.notifyOnBell); onAlertPrefsChange?() }
    }
    var notifyOnlyWhenInactive: Bool {
        get { defaults.bool(forKey: Keys.notifyOnlyWhenInactive) }
        set { set(newValue, Keys.notifyOnlyWhenInactive) }
    }
    /// Newline-separated substrings; a completed output line containing any of them fires
    /// a notification.
    var notifyWatchStrings: String {
        get { defaults.string(forKey: Keys.notifyWatchStrings) ?? "" }
        set { set(newValue, Keys.notifyWatchStrings); onAlertPrefsChange?() }
    }
    var triggers: [Trigger] {
        get {
            guard let s = defaults.string(forKey: Keys.triggers), let data = s.data(using: .utf8),
                  let list = try? JSONDecoder().decode([Trigger].self, from: data) else { return [] }
            return list
        }
        set {
            let s = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            set(s, Keys.triggers)
            onAlertPrefsChange?()
        }
    }

    var shellConfig: ShellConfig {
        ShellConfig(kind: shellKind,
                    customPath: customShellPath,
                    customArgs: customShellArgs,
                    useLoginArgs: useLoginShellArgs)
    }
}
