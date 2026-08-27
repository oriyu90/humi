import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppearancePane: View {
    @ObservedObject private var themes = ThemeStore.shared
    @ObservedObject private var settings = AppSettings.shared

    private var family: Theme { themes.activeFamily }
    private var editable: Bool { !family.isBuiltIn }

    /// Binding into the active *custom* theme; writing persists + re-applies live.
    private func t<V>(_ kp: WritableKeyPath<Theme, V>) -> Binding<V> {
        Binding(
            get: { family[keyPath: kp] },
            set: { newValue in
                var copy = family
                copy[keyPath: kp] = newValue
                themes.update(copy)
            }
        )
    }

    var body: some View {
        SettingsPane {
            SettingRow(label: L("appearance.mode")) {
                Picker("", selection: Binding(get: { themes.mode }, set: { themes.setMode($0) })) {
                    Text(L("appearance.mode.light")).tag(ThemeMode.light)
                    Text(L("appearance.mode.dark")).tag(ThemeMode.dark)
                    Text(L("appearance.mode.system")).tag(ThemeMode.system)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }

            SettingRow(label: L("appearance.theme")) {
                Picker("", selection: Binding(get: { themes.activeName }, set: { themes.setActive($0) })) {
                    ForEach(themes.allThemes) { th in Text(th.name).tag(th.name) }
                }
                .labelsHidden().frame(width: 220)
            }

            HStack(spacing: Hum.Space.sm) {
                Button(L("appearance.duplicate")) { themes.duplicate(family) }
                Button(L("appearance.delete")) { themes.delete(id: family.id) }
                    .disabled(!editable)
                Spacer()
                Button(L("appearance.import")) { importTheme() }
                Button(L("appearance.export")) { exportTheme() }
            }
            .font(Hum.Font.body(12))

            if !editable { settingsHint(L("appearance.builtin_note")) }

            Divider().overlay(Hum.hairline)

            // Font
            SettingRow(label: L("appearance.font_family")) {
                Picker("", selection: t(\.fontFamily)) {
                    ForEach(FontResolver.monospacedFamilies(), id: \.self) { fam in
                        Text(fam.isEmpty ? L("appearance.font_family.system") : fam).tag(fam)
                    }
                }.labelsHidden().frame(width: 220).disabled(!editable)
            }
            SettingRow(label: L("appearance.cjk_font")) {
                Picker("", selection: Binding(
                    get: { family.cjkFontFamily ?? "" },
                    set: { var c = family; c.cjkFontFamily = $0.isEmpty ? nil : $0; themes.update(c) }
                )) {
                    Text(L("appearance.cjk_font.none")).tag("")
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(width: 220).disabled(!editable)
            }
            SettingRow(label: L("settings.appearance.font_size")) {
                Slider(value: settings.bind(\.fontSize), in: 9...28, step: 1).frame(width: 180)
                Text(L("settings.appearance.pt", Int(settings.fontSize))).foregroundStyle(Hum.ink2).monospacedDigit()
            }

            // Cursor
            SettingRow(label: L("appearance.cursor_shape")) {
                Picker("", selection: Binding(
                    get: { family.cursorSpec.shape },
                    set: { var c = family; c.cursorSpec.shape = $0; themes.update(c) }
                )) {
                    Text(L("appearance.cursor.block")).tag(CursorSpec.Shape.block)
                    Text(L("appearance.cursor.underline")).tag(CursorSpec.Shape.underline)
                    Text(L("appearance.cursor.bar")).tag(CursorSpec.Shape.bar)
                }.labelsHidden().frame(width: 220).disabled(!editable)
            }
            Toggle(L("appearance.cursor_blink"), isOn: Binding(
                get: { family.cursorSpec.blink },
                set: { var c = family; c.cursorSpec.blink = $0; themes.update(c) }
            )).disabled(!editable)
            Toggle(L("appearance.bright_bold"), isOn: t(\.useBrightBold)).disabled(!editable)

            Divider().overlay(Hum.hairline)

            // Core colours
            Text(L("appearance.colors")).font(Hum.Font.display(13, weight: .bold)).foregroundStyle(Hum.ink)
            colorRow(L("appearance.color.background"), t(\.background))
            colorRow(L("appearance.color.foreground"), t(\.foreground))
            colorRow(L("appearance.color.cursor"), t(\.cursor))
            colorRow(L("appearance.color.selection"), t(\.selectionBackground))

            // ANSI 16
            Text(L("appearance.ansi")).font(Hum.Font.display(13, weight: .bold)).foregroundStyle(Hum.ink)
            ansiGrid(L("appearance.ansi.normal"), range: 0..<8)
            ansiGrid(L("appearance.ansi.bright"), range: 8..<16)
        }
    }

    private func colorRow(_ label: String, _ binding: Binding<HexColor>) -> some View {
        SettingRow(label: label) {
            ColorWellView(color: binding).disabled(!editable)
            Text(binding.wrappedValue.hexString).font(Hum.Font.mono(11)).foregroundStyle(Hum.ink2)
        }
    }

    private func ansiGrid(_ label: String, range: Range<Int>) -> some View {
        HStack(spacing: Hum.Space.sm) {
            Text(label).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2).frame(width: 48, alignment: .leading)
            ForEach(Array(range), id: \.self) { i in
                ColorWellView(color: Binding(
                    get: { family.ansi.indices.contains(i) ? family.ansi[i] : HexColor(0) },
                    set: { var c = family; if c.ansi.indices.contains(i) { c.ansi[i] = $0; themes.update(c) } }
                ))
                .frame(width: 30)
                .disabled(!editable)
            }
        }
    }

    // MARK: import / export

    private func exportTheme() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = family.name.replacingOccurrences(of: " ", with: "-") + ".humitheme"
        panel.allowedContentTypes = [UTType(filenameExtension: "humitheme") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? themes.exportTheme(family, to: url)
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "humitheme") ?? .json, .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        themes.importTheme(from: url)
    }
}
