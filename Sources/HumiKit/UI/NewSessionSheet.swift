import SwiftUI

/// Step 2 of the `+` flow: the folder was already chosen (or skipped) via an
/// `NSOpenPanel` run by `RootView`. Here the user picks *where* the session opens.
/// No `NSOpenPanel` is run from inside this sheet (that would nest modals).
struct NewSessionSheet: View {
    @ObservedObject var settings: AppSettings
    let folder: String?
    var onPickFolder: () -> Void
    /// workingDirectory? — nil == "open as-is" (home / login default)
    var onCreate: (String?) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Hum.Space.lg) {
            VStack(alignment: .leading, spacing: Hum.Space.xs) {
                Text("新しいセッション")
                    .font(Hum.Font.display(20, weight: .bold))
                    .foregroundStyle(Hum.ink)
                Text("開き方を選びます。")
                    .font(Hum.Font.body(13))
                    .foregroundStyle(Hum.ink2)
            }

            HStack(spacing: Hum.Space.sm) {
                Image(systemName: folder == nil ? "house" : "folder")
                    .foregroundStyle(Hum.ink2)
                Text(folder.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "フォルダ未選択（ホームで開く）")
                    .font(Hum.Font.mono(12))
                    .foregroundStyle(folder == nil ? Hum.ink2 : Hum.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Hum.Space.sm)
                Button(folder == nil ? "フォルダを選択…" : "変更…") { onPickFolder() }
                    .buttonStyle(.hum(.outline, accent: Hum.accent(1)))
            }
            .padding(Hum.Space.md)
            .background(RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous).fill(Hum.paper2))

            Divider().overlay(Hum.hairline)

            Button {
                onCreate(folder)
            } label: {
                actionLabel(title: folder == nil ? "そのまま開く（ホーム）" : "このフォルダで開く",
                            subtitle: "Humi 内のタイルでターミナルを開く",
                            systemImage: "square.split.2x2")
            }
            .buttonStyle(.hum(.push, accent: Hum.accent(0)))

            HStack {
                Spacer()
                Button("キャンセル") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Hum.ink2)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Hum.Space.xl)
        .frame(width: 460)
        .background(Hum.paper)
    }

    private func actionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: Hum.Space.sm) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Hum.Font.display(14, weight: .semibold))
                Text(subtitle).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
