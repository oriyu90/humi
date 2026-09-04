import SwiftUI

struct GeneralPane: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var hotkeyChord = AppSettings.shared.globalHotkeyChord

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
            if settings.appLanguage != "system" {
                settingsHint(L("settings.general.language.menu_hint"))
            }

            Toggle(L("settings.general.notes_on_launch"), isOn: settings.bind(\.notesVisible))

            SettingRow(label: L("settings.general.scrollback")) {
                Text(L("settings.general.lines", settings.scrollbackLines))
                    .foregroundStyle(Hum.ink2).monospacedDigit()
                Stepper("", value: settings.bind(\.scrollbackLines), in: 1000...200_000, step: 1000)
                    .labelsHidden()
            }
            settingsHint(L("settings.general.scrollback_hint"))

            Divider().padding(.vertical, Hum.Space.sm)

            Toggle(L("settings.general.global_hotkey"), isOn: settings.bind(\.globalHotkeyEnabled))
            if settings.globalHotkeyEnabled {
                SettingRow(label: L("settings.general.global_hotkey.chord")) {
                    KeyRecorder(chord: $hotkeyChord) { c in settings.globalHotkeyChord = c }
                        .frame(width: 140, height: 24)
                }
                if !HotKeyCenter.shared.isRegistered {
                    settingsHint(L("settings.general.global_hotkey.failed"))
                }
            }
            settingsHint(L("settings.general.global_hotkey.hint"))
        }
    }
}
