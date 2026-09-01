import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var themes = ThemeStore.shared

    public init() {}

    private var isDark: Bool { themes.resolvedTheme.appAppearance == .dark }

    public var body: some View {
        TabView {
            GeneralPane().tabItem { Label(L("settings.tab.general"), systemImage: "gearshape") }
            AppearancePane().tabItem { Label(L("settings.tab.appearance"), systemImage: "paintpalette") }
            TerminalPane().tabItem { Label(L("settings.tab.terminal"), systemImage: "terminal") }
            ProfilesPane().tabItem { Label(L("settings.tab.profiles"), systemImage: "person.crop.rectangle.stack") }
            ShortcutsPane().tabItem { Label(L("settings.tab.shortcuts"), systemImage: "keyboard") }
            StatusBarPane().tabItem { Label(L("settings.tab.statusbar"), systemImage: "menubar.rectangle") }
            AlertsPane().tabItem { Label(L("settings.tab.alerts"), systemImage: "bell.badge") }
            ShellPane().tabItem { Label(L("settings.tab.shell"), systemImage: "chevron.left.forwardslash.chevron.right") }
        }
        .frame(width: 620, height: 480)
        .background(Hum.paper)
        .environment(\.locale, loc.locale)
        .preferredColorScheme(isDark ? .dark : .light)
        // `.preferredColorScheme` alone doesn't repaint an already-open Settings
        // window when the in-app Light/Dark mode flips — force the NSWindow's
        // appearance on every update pass.
        .background(SettingsAppearanceSync(dark: isDark))
    }
}

/// Keeps the open Settings window's `NSAppearance` in step with the in-app theme mode.
private struct SettingsAppearanceSync: NSViewRepresentable {
    let dark: Bool
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        let wanted: NSAppearance.Name = dark ? .darkAqua : .aqua
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.appearance?.name != wanted {
                window.appearance = NSAppearance(named: wanted)
            }
        }
    }
}

// MARK: - Shared pane layout

/// Top-aligned, left-aligned scrolling pane body. (`Form` bottom-aligned few rows and
/// clipped long slider/stepper labels — see the 1.0.1 debug notes.)
struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Hum.Space.md) {
                content()
            }
            .padding(Hum.Space.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Hum.paper)
    }
}

/// `label` on the left, `control` on the right — labels never push controls off-edge.
struct SettingRow<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Hum.ink)
            Spacer(minLength: Hum.Space.md)
            control()
        }
    }
}

func settingsHint(_ text: String) -> some View {
    Text(text).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
        .fixedSize(horizontal: false, vertical: true)
}
