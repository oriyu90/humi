import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loc = Localization.shared

    public init() {}

    public var body: some View {
        TabView {
            general.tabItem { Label(L("settings.tab.general"), systemImage: "gearshape") }
            shell.tabItem { Label(L("settings.tab.shell"), systemImage: "terminal") }
            appearance.tabItem { Label(L("settings.tab.appearance"), systemImage: "paintpalette") }
        }
        .frame(width: 500, height: 360)
        .background(Hum.paper)
        .environment(\.locale, loc.locale)
    }

    /// Each tab's rows, top-aligned and left-aligned with room for labels.
    /// (`Form` here bottom-aligned its few rows and let long Slider/Stepper labels
    /// push their controls off the leading edge — hence the plain VStack + explicit
    /// label/control HStacks.)
    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Hum.Space.md) {
            content()
            Spacer(minLength: 0)
        }
        .padding(Hum.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var general: some View {
        tab {
            HStack {
                Text(L("settings.general.language"))
                Spacer()
                Picker("", selection: settings.bind(\.appLanguage)) {
                    ForEach(Localization.supported, id: \.self) { code in
                        Text(Localization.label(for: code)).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }
            Toggle(L("settings.general.notes_on_launch"), isOn: settings.bind(\.notesVisible))
            HStack {
                Text(L("settings.general.scrollback"))
                Spacer()
                Text(L("settings.general.lines", settings.scrollbackLines)).foregroundStyle(Hum.ink2).monospacedDigit()
                Stepper("", value: settings.bind(\.scrollbackLines), in: 1000...200_000, step: 1000)
                    .labelsHidden()
            }
            hint(L("settings.general.scrollback_hint"))
        }
    }

    private var shell: some View {
        tab {
            Picker(L("settings.shell.shell"), selection: settings.bind(\.shellKind)) {
                ForEach(ShellKind.allCases) { Text($0.label).tag($0) }
            }
            if settings.shellKind == .custom {
                TextField(L("settings.shell.custom_path"), text: settings.bind(\.customShellPath))
                TextField(L("settings.shell.custom_args"), text: settings.bind(\.customShellArgs))
            } else {
                Toggle(L("settings.shell.login_toggle"), isOn: settings.bind(\.useLoginShellArgs))
            }
            hint(L("settings.shell.hint"))
        }
    }

    private var appearance: some View {
        tab {
            HStack {
                Text(L("settings.appearance.font_size"))
                Spacer()
                Text(L("settings.appearance.pt", Int(settings.fontSize))).foregroundStyle(Hum.ink2).monospacedDigit()
            }
            Slider(value: settings.bind(\.fontSize), in: 9...22, step: 1).labelsHidden()
            hint(L("settings.appearance.hint"))
        }
    }
}
