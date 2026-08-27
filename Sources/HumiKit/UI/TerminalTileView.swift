import SwiftUI

/// One session, framed as a Hum card: rounded, hairline, an accent tint that deepens
/// on hover, a title bar with restart / open-externally / maximise / close.
struct TerminalTileView: View {
    let session: Session
    let isMaximized: Bool
    @ObservedObject var store: SessionStore
    @ObservedObject var settings: AppSettings

    @State private var hovering = false

    private var accent: Hum.Accent { Hum.accent(session.accentIndex) }
    private var exitCode: Int32? { store.exitCodes[session.id] }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().overlay(Hum.hairline)
            terminalBody
        }
        .background(Hum.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Hum.Radius.tile, style: .continuous)
                .strokeBorder(isMaximized ? accent.edge.opacity(0.9) : Hum.hairline,
                              lineWidth: isMaximized ? 2 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: Hum.Radius.tile, style: .continuous)
                .fill(accent.tint.opacity(hovering ? 0.12 : 0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: Hum.Radius.tile, style: .continuous))
        .shadow(color: Hum.ink.opacity(hovering ? 0.14 : 0.08),
                radius: hovering ? 18 : 10, x: 0, y: hovering ? 10 : 6)
        .onHover { h in
            withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { hovering = h }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("セッション: \(session.title)")
    }

    private var titleBar: some View {
        HStack(spacing: Hum.Space.sm) {
            Circle().fill(accent.tint).frame(width: 9, height: 9)
                .overlay(Circle().stroke(accent.edge.opacity(0.6), lineWidth: 1))
                .accessibilityHidden(true)

            Text(session.title)
                .font(Hum.Font.display(12.5, weight: .semibold))
                .foregroundStyle(Hum.ink)
                .lineLimit(1)
                .truncationMode(.middle)

            if let code = exitCode {
                Text(code == 0 ? "終了" : "終了 (\(code))")
                    .font(Hum.Font.mono(10))
                    .foregroundStyle(Hum.ink2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Hum.paper3))
                    .accessibilityLabel(code == 0 ? "プロセス終了" : "プロセス終了、コード \(code)")
            }

            Spacer(minLength: Hum.Space.sm)

            if exitCode != nil {
                tileButton("arrow.clockwise", label: "セッションを再起動") {
                    store.restart(session.id, settings: settings)
                }
            }
            tileButton(isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                       label: isMaximized ? "タイル表示に戻す" : "最大化") {
                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { store.toggleMaximize(session.id) }
            }
            tileButton("xmark", label: "セッションを閉じる") {
                store.close(session.id)
            }
        }
        .padding(.horizontal, Hum.Space.md)
        .padding(.vertical, Hum.Space.sm)
        .background(Hum.paper.opacity(0.9))
    }

    private var terminalBody: some View {
        TerminalEmulatorView(
            session: session,
            settings: settings,
            onTitle: { store.updateTitle(session.id, $0) },
            onDirectory: { dir in
                if let dir { store.updateWorkingDirectory(session.id, dir) }
            },
            onExit: { code in store.markExited(session.id, code: code) }
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .opacity(exitCode == nil ? 1 : 0.55)
    }

    private func tileButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Hum.ink2)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
