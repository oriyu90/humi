import SwiftUI
import AppKit

/// One session, framed as a Hum card: rounded, hairline, an accent tint that deepens
/// on hover, a title bar with restart / maximise / close, and a context menu for
/// rename / colour / on-exit / logging / open-selection.
struct TerminalTileView: View {
    let session: Session
    let isMaximized: Bool
    /// Draw the accent focus ring — this is the pane the keyboard is in.
    var isFocused: Bool = false
    @ObservedObject var store: SessionStore
    @ObservedObject var settings: AppSettings

    @State private var hovering = false
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmingClose = false

    private var accent: Hum.Accent { Hum.accent(session.effectiveAccent) }
    private var exitCode: Int32? { store.exitCodes[session.id] }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().overlay(Hum.hairline)
            terminalBody
            if settings.statusBarEnabled {
                Divider().overlay(Hum.hairline)
                StatusBarView(session: session, settings: settings)
            }
        }
        .background(Hum.paper)
        .overlay(
            RoundedRectangle(cornerRadius: Hum.Radius.tile, style: .continuous)
                .strokeBorder((isMaximized || isFocused) ? accent.edge.opacity(0.9) : Hum.hairline,
                              lineWidth: (isMaximized || isFocused) ? 2 : 1)
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
        .contextMenu { menu }
        .alert(L("tile.rename"), isPresented: $renaming) {
            TextField(L("tile.rename.prompt"), text: $draftName)
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("tile.rename")) { store.setCustomTitle(session.id, draftName) }
        }
        .confirmationDialog(L("tile.close_confirm.title"), isPresented: $confirmingClose, titleVisibility: .visible) {
            Button(L("tile.close_confirm.close"), role: .destructive) { store.close(session.id) }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("tile.close_confirm.message"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("tile.a11y", session.displayTitle))
    }

    // MARK: title bar

    private var titleBar: some View {
        HStack(spacing: Hum.Space.sm) {
            Circle().fill(accent.tint).frame(width: 9, height: 9)
                .overlay(Circle().stroke(accent.edge.opacity(0.6), lineWidth: 1))
                .accessibilityHidden(true)

            Text(session.displayTitle)
                .font(Hum.Font.display(12.5, weight: .semibold))
                .foregroundStyle(Hum.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .onTapGesture(count: 2) { beginRename() }

            if session.logging {
                Image(systemName: "record.circle").font(.system(size: 10)).foregroundStyle(Hum.coral)
                    .accessibilityLabel(L("tile.logging"))
            }

            if let code = exitCode {
                Text(code == 0 ? L("tile.exited") : L("tile.exited_code", Int(code)))
                    .font(Hum.Font.mono(10))
                    .foregroundStyle(Hum.ink2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Hum.paper3))
                    .accessibilityLabel(code == 0 ? L("tile.exited.a11y") : L("tile.exited_code.a11y", Int(code)))
            }

            Spacer(minLength: Hum.Space.sm)

            if exitCode != nil {
                tileButton("arrow.clockwise", label: L("tile.restart")) {
                    store.restart(session.id, settings: settings)
                }
            }
            tileButton(isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                       label: isMaximized ? L("tile.restore") : L("tile.maximize")) {
                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { store.toggleMaximize(session.id) }
            }
            tileButton("xmark", label: L("tile.close")) { requestClose() }
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
        .padding(.horizontal, max(6, CGFloat(settings.terminalMargin)))
        .padding(.vertical, max(4, CGFloat(settings.terminalMargin) * 0.66))
        .opacity(exitCode == nil ? 1 : 0.55)
    }

    // MARK: context menu

    @ViewBuilder private var menu: some View {
        Button(L("tile.rename")) { beginRename() }

        Menu(L("tile.color")) {
            ForEach(0..<Hum.accents.count, id: \.self) { i in
                Button {
                    store.setAccentOverride(session.id, i == session.accentIndex ? nil : i)
                } label: {
                    Label {
                        Text(colorName(i))
                    } icon: {
                        Image(systemName: session.effectiveAccent == i ? "checkmark.circle.fill" : "circle.fill")
                            .foregroundStyle(Hum.accent(i).tint)
                    }
                }
            }
        }

        Picker(L("tile.on_exit"), selection: Binding(
            get: { session.onExit },
            set: { store.setOnExit(session.id, $0) }
        )) {
            Text(L("tile.on_exit.keep")).tag(OnExit.keep)
            Text(L("tile.on_exit.restart")).tag(OnExit.restart)
            Text(L("tile.on_exit.close")).tag(OnExit.close)
        }

        Toggle(L("tile.logging"), isOn: Binding(
            get: { session.logging },
            set: { store.setLogging(session.id, $0) }
        ))

        Divider()

        Button(L("tile.open_selection")) {
            _ = TerminalRegistry.shared.existing(session.id)?.openSelection()
        }
        if session.workingDirectory != nil {
            Button(L("tile.reveal")) {
                if let dir = session.workingDirectory {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dir)])
                }
            }
        }

        Divider()
        Button(L("tile.close"), role: .destructive) { requestClose() }
    }

    // MARK: helpers

    private func beginRename() {
        draftName = session.customTitle ?? session.displayTitle
        renaming = true
    }

    private func requestClose() {
        if store.closeNeedsConfirmation(session.id) { confirmingClose = true }
        else { store.close(session.id) }
    }

    private func colorName(_ i: Int) -> String {
        ["Pear", "Cyan", "Coral", "Mint", "Lavender"][i % 5]
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
