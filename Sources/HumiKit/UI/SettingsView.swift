import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var themes = ThemeStore.shared

    public init() {}

    public var body: some View {
        TabView {
            GeneralPane().tabItem { Label(L("settings.tab.general"), systemImage: "gearshape") }
            AppearancePane().tabItem { Label(L("settings.tab.appearance"), systemImage: "paintpalette") }
            TerminalPane().tabItem { Label(L("settings.tab.terminal"), systemImage: "terminal") }
            ProfilesPane().tabItem { Label(L("settings.tab.profiles"), systemImage: "person.crop.rectangle.stack") }
            ShortcutsPane().tabItem { Label(L("settings.tab.shortcuts"), systemImage: "keyboard") }
            ShellPane().tabItem { Label(L("settings.tab.shell"), systemImage: "chevron.left.forwardslash.chevron.right") }
        }
        .frame(width: 620, height: 480)
        .background(Hum.paper)
        .environment(\.locale, loc.locale)
        .preferredColorScheme(themes.resolvedTheme.appAppearance == .dark ? .dark : .light)
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
