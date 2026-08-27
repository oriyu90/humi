import AppKit
import SwiftUI

enum ThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case light, dark, system
    var id: String { rawValue }
}

/// Owns the active theme family, the light/dark mode, and the user's custom themes.
/// `resolvedTheme` is what terminals + app chrome actually render; it changes when the
/// user edits a theme, switches families, switches mode, or (under `.system`) the OS
/// appearance flips. `onChange` fans the resolved theme out to live terminals.
@MainActor
public final class ThemeStore: ObservableObject {
    public static let shared = ThemeStore()
    static let fileName = "themes.json"

    @Published var customThemes: [Theme] = []
    @Published var activeName: String = Theme.humLight.name
    @Published var mode: ThemeMode = .system

    /// Called after `resolvedTheme` changes so `TerminalRegistry` can re-apply it.
    public var onChange: (() -> Void)?

    private struct Disk: Codable {
        var custom: [Theme]
        var activeName: String
        var mode: ThemeMode
    }

    private var appearanceObserver: NSObjectProtocol?

    private init() {
        if let d = Persistence.decode(Disk.self, from: Self.fileName) {
            customThemes = d.custom.map { var t = $0; t.isBuiltIn = false; return t }
            activeName = d.activeName
            mode = d.mode
        }
        // OS light/dark flips (only relevant under `.system`).
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.mode == .system else { return }
                self.objectWillChange.send()
                self.onChange?()
            }
        }
    }

    var allThemes: [Theme] { Theme.builtIns + customThemes }

    func theme(named name: String) -> Theme? { allThemes.first { $0.name == name } }

    /// The family the user picked (before light/dark resolution).
    var activeFamily: Theme { theme(named: activeName) ?? Theme.humLight }

    /// True when the OS is currently in dark mode.
    static var osIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// The theme actually rendered right now.
    var resolvedTheme: Theme {
        let wantDark: Bool
        switch mode {
        case .light:  wantDark = false
        case .dark:   wantDark = true
        case .system: wantDark = Self.osIsDark
        }
        let family = activeFamily
        let isDark = family.appAppearance == .dark
        if wantDark == isDark { return family }
        // Switch to the paired sibling of the opposite appearance, if it exists.
        if let paired = family.pairedThemeName, let sib = theme(named: paired),
           (sib.appAppearance == .dark) == wantDark {
            return sib
        }
        // Otherwise fall back to a sensible built-in of the wanted appearance.
        return wantDark ? Theme.humDark : Theme.humLight
    }

    // MARK: mutations

    /// Pick a theme family. Also snaps `mode` to that family's own appearance so the
    /// terminal shows exactly the theme you chose (System is opt-in via `setMode`).
    func setActive(_ name: String) {
        activeName = name
        if let picked = theme(named: name) {
            mode = picked.appAppearance == .dark ? .dark : .light
        }
        changed()
    }
    func setMode(_ m: ThemeMode) { mode = m; changed() }

    func addCustom(_ theme: Theme) {
        var t = theme; t.isBuiltIn = false
        customThemes.append(t)
        activeName = t.name
        changed()
    }

    func update(_ theme: Theme) {
        guard let i = customThemes.firstIndex(where: { $0.id == theme.id }) else { return }
        customThemes[i] = theme
        changed()
    }

    func delete(id: UUID) {
        guard let i = customThemes.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = customThemes[i].name == activeName
        customThemes.remove(at: i)
        if wasActive { activeName = Theme.humLight.name }
        changed()
    }

    /// Copy any theme into an editable custom one with a unique name.
    @discardableResult
    func duplicate(_ theme: Theme) -> Theme {
        var t = theme
        t.id = UUID()
        t.isBuiltIn = false
        t.name = uniqueName(base: theme.name)
        customThemes.append(t)
        activeName = t.name
        changed()
        return t
    }

    func uniqueName(base: String) -> String {
        var name = "\(base) copy"
        var n = 2
        let taken = Set(allThemes.map(\.name))
        while taken.contains(name) { name = "\(base) copy \(n)"; n += 1 }
        return name
    }

    private func changed() {
        persist()
        objectWillChange.send()
        onChange?()
    }

    private func persist() {
        Persistence.encode(Disk(custom: customThemes, activeName: activeName, mode: mode), to: Self.fileName)
    }

    // MARK: import / export

    func exportTheme(_ theme: Theme, to url: URL) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(theme).write(to: url, options: .atomic)
    }

    @discardableResult
    func importTheme(from url: URL) -> Theme? {
        guard let data = try? Data(contentsOf: url),
              var theme = try? JSONDecoder().decode(Theme.self, from: data) else { return nil }
        theme.id = UUID()
        theme.isBuiltIn = false
        theme.name = Set(allThemes.map(\.name)).contains(theme.name) ? uniqueName(base: theme.name) : theme.name
        customThemes.append(theme)
        activeName = theme.name
        changed()
        return theme
    }
}
