import SwiftUI

struct GeneralPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsPane {
            SettingRow(label: L("settings.general.language")) {
                Picker("", selection: settings.bind(\.appLanguage)) {
                    ForEach(Localization.supported, id: \.self) { code in
                        Text(Localization.label(for: code)).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }

            Toggle(L("settings.general.notes_on_launch"), isOn: settings.bind(\.notesVisible))

            SettingRow(label: L("settings.general.scrollback")) {
                Text(L("settings.general.lines", settings.scrollbackLines))
                    .foregroundStyle(Hum.ink2).monospacedDigit()
                Stepper("", value: settings.bind(\.scrollbackLines), in: 1000...200_000, step: 1000)
                    .labelsHidden()
            }
            settingsHint(L("settings.general.scrollback_hint"))
        }
    }
}
