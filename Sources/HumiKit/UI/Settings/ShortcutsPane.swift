import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShortcutsPane: View {
    @ObservedObject private var store = KeymapStore.shared

    var body: some View {
        SettingsPane {
            HStack {
                Button(L("shortcuts.reset")) { store.resetAll() }
                Spacer()
                Button(L("shortcuts.import")) { importMap() }
                Button(L("shortcuts.export")) { exportMap() }
            }
            .font(Hum.Font.body(12))

            ForEach(HumiAction.allCases) { action in
                let chord = store.chord(for: action)
                let conflicts = store.conflicts(chord, excluding: action)
                HStack {
                    Text(action.label).foregroundStyle(Hum.ink)
                    if !conflicts.isEmpty {
                        Text("(\(L("shortcuts.conflict")))").font(Hum.Font.body(10)).foregroundStyle(Hum.coral)
                    }
                    Spacer()
                    KeyRecorder(chord: Binding(get: { chord }, set: { store.set(action, $0) })) { c in
                        store.set(action, c)
                    }
                    .frame(width: 110, height: 22)
                }
            }

            settingsHint(L("shortcuts.hint"))
        }
    }

    private func exportMap() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "humi.humikeys"
        panel.allowedContentTypes = [UTType(filenameExtension: "humikeys") ?? .json]
        if panel.runModal() == .OK, let url = panel.url { try? store.exportMap(to: url) }
    }
    private func importMap() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "humikeys") ?? .json, .json]
        if panel.runModal() == .OK, let url = panel.url { store.importMap(from: url) }
    }
}
