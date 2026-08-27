import SwiftUI

struct ShellPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsPane {
            SettingRow(label: L("settings.shell.shell")) {
                Picker("", selection: settings.bind(\.shellKind)) {
                    ForEach(ShellKind.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 200)
            }
            if settings.shellKind == .custom {
                TextField(L("settings.shell.custom_path"), text: settings.bind(\.customShellPath))
                TextField(L("settings.shell.custom_args"), text: settings.bind(\.customShellArgs))
            } else {
                Toggle(L("settings.shell.login_toggle"), isOn: settings.bind(\.useLoginShellArgs))
            }
            settingsHint(L("settings.shell.hint"))
        }
    }
}
