import SwiftUI
import AppKit

struct TerminalPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsPane {
            Toggle(L("terminal.option_as_meta"), isOn: settings.bind(\.optionAsMeta))
            Toggle(L("terminal.mouse_reporting"), isOn: settings.bind(\.mouseReporting))
            Toggle(L("terminal.copy_on_select"), isOn: settings.bind(\.copyOnSelect))
            Toggle(L("terminal.confirm_paste"), isOn: settings.bind(\.confirmMultilinePaste))
            Toggle(L("terminal.unlimited_scrollback"), isOn: settings.bind(\.unlimitedScrollback))

            SettingRow(label: L("terminal.scrollbar")) {
                Picker("", selection: settings.bind(\.scrollbarStyle)) {
                    Text(L("terminal.scrollbar.overlay")).tag(ScrollbarStyle.overlay)
                    Text(L("terminal.scrollbar.legacy")).tag(ScrollbarStyle.legacy)
                }.labelsHidden().frame(width: 180)
            }

            SettingRow(label: L("terminal.bell")) {
                Picker("", selection: settings.bind(\.bellStyle)) {
                    Text(L("terminal.bell.off")).tag(BellStyle.off)
                    Text(L("terminal.bell.sound")).tag(BellStyle.sound)
                    Text(L("terminal.bell.visual")).tag(BellStyle.visual)
                    Text(L("terminal.bell.notify")).tag(BellStyle.notify)
                }.labelsHidden().frame(width: 180)
            }

            SettingRow(label: L("terminal.confirm_close")) {
                Picker("", selection: settings.bind(\.confirmClose)) {
                    Text(L("terminal.confirm_close.never")).tag(ConfirmClose.never)
                    Text(L("terminal.confirm_close.busy")).tag(ConfirmClose.busy)
                    Text(L("terminal.confirm_close.always")).tag(ConfirmClose.always)
                }.labelsHidden().frame(width: 180)
            }

            SettingRow(label: L("terminal.scroll_sensitivity")) {
                Slider(value: settings.bind(\.scrollSensitivity), in: 0.2...5, step: 0.1)
                    .frame(width: 180)
                Text(String(format: "%.1f×", settings.scrollSensitivity))
                    .foregroundStyle(Hum.ink2).monospacedDigit()
            }

            SettingRow(label: L("terminal.margin")) {
                Slider(value: settings.bind(\.terminalMargin), in: 0...24, step: 1)
                    .frame(width: 180)
                Text("\(Int(settings.terminalMargin)) px").foregroundStyle(Hum.ink2).monospacedDigit()
            }

            Divider().overlay(Hum.hairline)

            Text(L("terminal.editor_command")).foregroundStyle(Hum.ink)
            TextField("", text: settings.bind(\.editorCommand))
                .font(Hum.Font.mono(12))
            settingsHint(L("terminal.editor_command.hint"))
        }
    }
}
