import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        TabView {
            general.tabItem { Label("一般", systemImage: "gearshape") }
            shell.tabItem { Label("シェル", systemImage: "terminal") }
            appearance.tabItem { Label("外観", systemImage: "paintpalette") }
        }
        .frame(width: 460, height: 340)
        .background(Hum.paper)
    }

    private var general: some View {
        Form {
            Toggle("起動時にメモを表示", isOn: settings.bind(\.notesVisible))
            Stepper("スクロールバック: \(settings.scrollbackLines) 行",
                    value: settings.bind(\.scrollbackLines), in: 1000...200_000, step: 1000)
            Text("スクロールバックの変更は次に開くセッションから反映されます。")
                .font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
        }
        .padding(Hum.Space.lg)
    }

    private var shell: some View {
        Form {
            Picker("シェル", selection: settings.bind(\.shellKind)) {
                ForEach(ShellKind.allCases) { Text($0.label).tag($0) }
            }
            if settings.shellKind == .custom {
                TextField("実行パス", text: settings.bind(\.customShellPath))
                TextField("引数（スペース区切り）", text: settings.bind(\.customShellArgs))
            } else {
                Toggle("ログインシェルとして起動（-l / argv0 に -）", isOn: settings.bind(\.useLoginShellArgs))
            }
            Text("変更は次に開くセッションから反映されます。")
                .font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
        }
        .padding(Hum.Space.lg)
    }

    private var appearance: some View {
        Form {
            Slider(value: settings.bind(\.fontSize), in: 9...22, step: 1) {
                Text("フォントサイズ: \(Int(settings.fontSize)) pt")
            }
            Text("Humi はライトテーマ（Hum）です。")
                .font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
        }
        .padding(Hum.Space.lg)
    }
}
