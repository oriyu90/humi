import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProfilesPane: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var themes = ThemeStore.shared
    @State private var selectedID: UUID?

    private var selected: Profile? { store.profiles.first { $0.id == selectedID } }

    var body: some View {
        HStack(spacing: 0) {
            list
            Divider().overlay(Hum.hairline)
            detail
        }
        .background(Hum.paper)
    }

    private var list: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(store.profiles) { p in
                    Label(p.name, systemImage: p.icon).tag(p.id)
                }
            }
            .frame(width: 180)
            HStack(spacing: 4) {
                Button { addProfile() } label: { Image(systemName: "plus") }
                Button { if let p = selected { store.delete(id: p.id); selectedID = store.profiles.first?.id } }
                    label: { Image(systemName: "minus") }
                    .disabled(selected == nil)
                Button { if let p = selected { selectedID = store.duplicate(p).id } }
                    label: { Image(systemName: "plus.square.on.square") }
                    .disabled(selected == nil)
                Spacer()
                Button { importProfile() } label: { Image(systemName: "square.and.arrow.down") }
                Button { exportProfile() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(selected == nil)
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    @ViewBuilder private var detail: some View {
        if let p = selected {
            editor(for: p)
        } else {
            VStack {
                Spacer()
                Text(store.profiles.isEmpty ? L("profiles.empty") : L("profiles.none_selected"))
                    .foregroundStyle(Hum.ink2).font(Hum.Font.body(12))
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func b<V>(_ p: Profile, _ kp: WritableKeyPath<Profile, V>) -> Binding<V> {
        Binding(get: { p[keyPath: kp] }, set: { var c = p; c[keyPath: kp] = $0; store.update(c) })
    }

    private func editor(for p: Profile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Hum.Space.md) {
                Toggle(L("profiles.default"), isOn: Binding(
                    get: { store.defaultProfileID == p.id },
                    set: { store.setDefault($0 ? p.id : nil) }
                ))

                SettingRow(label: L("profiles.name")) {
                    TextField("", text: b(p, \.name)).frame(width: 220)
                }
                SettingRow(label: L("profiles.icon")) {
                    TextField("", text: b(p, \.icon)).frame(width: 220)
                }
                SettingRow(label: L("profiles.color")) {
                    Picker("", selection: b(p, \.colorIndex)) {
                        ForEach(0..<Hum.accents.count, id: \.self) { i in
                            Text(["Pear","Cyan","Coral","Mint","Lavender"][i % 5]).tag(i)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                SettingRow(label: L("settings.shell.shell")) {
                    Picker("", selection: Binding(
                        get: { ShellKind(rawValue: p.shellKind) ?? .login },
                        set: { var c = p; c.shellKind = $0.rawValue; store.update(c) }
                    )) {
                        ForEach(ShellKind.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 220)
                }
                if ShellKind(rawValue: p.shellKind) == .custom {
                    TextField(L("settings.shell.custom_path"), text: b(p, \.customShellPath))
                    TextField(L("settings.shell.custom_args"), text: b(p, \.customShellArgs))
                }

                SettingRow(label: L("profiles.theme")) {
                    Picker("", selection: Binding(
                        get: { p.themeName ?? "" },
                        set: { var c = p; c.themeName = $0.isEmpty ? nil : $0; store.update(c) }
                    )) {
                        Text(L("profiles.theme.global")).tag("")
                        ForEach(themes.allThemes) { Text($0.name).tag($0.name) }
                    }.labelsHidden().frame(width: 220)
                }

                Text(L("profiles.startup")).foregroundStyle(Hum.ink)
                TextField("", text: b(p, \.startupCommand)).font(Hum.Font.mono(12))

                SettingRow(label: L("profiles.cwd")) {
                    Text(p.cwd.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "—")
                        .font(Hum.Font.mono(11)).foregroundStyle(Hum.ink2).lineLimit(1).truncationMode(.middle)
                    Button(L("profiles.cwd.choose")) { chooseCwd(p) }
                    if p.cwd != nil { Button(L("profiles.cwd.clear")) { var c = p; c.cwd = nil; store.update(c) } }
                }

                Text(L("profiles.env")).foregroundStyle(Hum.ink)
                TextEditor(text: Binding(
                    get: { p.env.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n") },
                    set: { var c = p; c.env = parseEnv($0); store.update(c) }
                ))
                .font(Hum.Font.mono(11)).frame(height: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Hum.hairline))

                SettingRow(label: L("profiles.scrollback")) {
                    TextField("", text: Binding(
                        get: { p.scrollback.map(String.init) ?? "" },
                        set: { var c = p; c.scrollback = Int($0); store.update(c) }
                    )).frame(width: 100)
                }
                Toggle(L("profiles.logging"), isOn: b(p, \.loggingDefault))
                Spacer()
            }
            .padding(Hum.Space.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func parseEnv(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let k = parts[0].trimmingCharacters(in: .whitespaces)
                if !k.isEmpty { dict[k] = String(parts[1]) }
            }
        }
        return dict
    }

    private func addProfile() {
        let p = Profile(name: store.uniqueName(base: "Profile"))
        store.add(p)
        selectedID = p.id
    }

    private func chooseCwd(_ p: Profile) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let path = panel.url?.path {
            var c = p; c.cwd = path; store.update(c)
        }
    }

    private func exportProfile() {
        guard let p = selected else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = p.name.replacingOccurrences(of: " ", with: "-") + ".humiprofile"
        panel.allowedContentTypes = [UTType(filenameExtension: "humiprofile") ?? .json]
        if panel.runModal() == .OK, let url = panel.url { try? store.export(p, to: url) }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "humiprofile") ?? .json, .json]
        if panel.runModal() == .OK, let url = panel.url { selectedID = store.importProfile(from: url)?.id }
    }
}
