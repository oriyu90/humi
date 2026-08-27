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
        .frame(width: 500, height: 360)
        .background(Hum.paper)
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
            Toggle("起動時にメモを表示", isOn: settings.bind(\.notesVisible))
            HStack {
                Text("スクロールバック")
                Spacer()
                Text("\(settings.scrollbackLines) 行").foregroundStyle(Hum.ink2).monospacedDigit()
                Stepper("", value: settings.bind(\.scrollbackLines), in: 1000...200_000, step: 1000)
                    .labelsHidden()
            }
            hint("スクロールバックの変更は次に開くセッションから反映されます。")
        }
    }

    private var shell: some View {
        tab {
            Picker("シェル", selection: settings.bind(\.shellKind)) {
                ForEach(ShellKind.allCases) { Text($0.label).tag($0) }
            }
            if settings.shellKind == .custom {
                TextField("実行パス", text: settings.bind(\.customShellPath))
                TextField("引数（スペース区切り）", text: settings.bind(\.customShellArgs))
            } else {
                Toggle("ログインシェルとして起動（-l / argv0 に -）", isOn: settings.bind(\.useLoginShellArgs))
            }
            hint("変更は次に開くセッションから反映されます。")
        }
    }

    private var appearance: some View {
        tab {
            HStack {
                Text("フォントサイズ")
                Spacer()
                Text("\(Int(settings.fontSize)) pt").foregroundStyle(Hum.ink2).monospacedDigit()
            }
            Slider(value: settings.bind(\.fontSize), in: 9...22, step: 1).labelsHidden()
            hint("開いているセッションへ即座に反映されます。Humi はライトテーマ（Hum）です。")
        }
    }
}
