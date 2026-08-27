import SwiftUI

struct StatusBarPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsPane {
            Toggle(L("statusbar.enabled"), isOn: settings.bind(\.statusBarEnabled))
            Divider().overlay(Hum.hairline)
            Group {
                Toggle(L("statusbar.cwd"), isOn: settings.bind(\.statusCwd))
                Toggle(L("statusbar.shell"), isOn: settings.bind(\.statusShell))
                Toggle(L("statusbar.git"), isOn: settings.bind(\.statusGit))
                Toggle(L("statusbar.process"), isOn: settings.bind(\.statusProcess))
                Toggle(L("statusbar.clock"), isOn: settings.bind(\.statusClock))
            }
            .disabled(!settings.statusBarEnabled)
            settingsHint(L("statusbar.hint"))
        }
    }
}
