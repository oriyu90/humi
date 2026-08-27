import SwiftUI
import AppKit

public extension Notification.Name {
    /// Posted by the ⌘N command; RootView opens the new-session flow.
    static let humiNewSession = Notification.Name("humi.newSession")
    /// Posted by the ⌘K command; clears the focused session's scrollback.
    static let humiClearBuffer = Notification.Name("humi.clearBuffer")
}

public struct RootView: View {
    public init() {}

    @StateObject private var store = SessionStore()
    @ObservedObject private var notes = NotesStore.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var showingNewSheet = false
    @State private var pendingFolder: String?
    @Environment(\.scenePhase) private var scenePhase

    public var body: some View {
        HSplitView {
            SessionGridView(store: store, settings: settings, onNew: beginNewSession)
                .frame(minWidth: 420)

            if settings.notesVisible {
                NotesSidebarView(notes: notes, settings: settings)
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 520)
            }
        }
        .background(Hum.paper2)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: Hum.Space.sm) {
                    CharacterMark(burstTrigger: store.sessions.count)
                    Text("Humi").font(Hum.Font.display(15, weight: .bold)).foregroundStyle(Hum.ink)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) {
                        settings.notesVisible.toggle()
                    }
                } label: {
                    Image(systemName: settings.notesVisible ? "sidebar.right" : "sidebar.trailing")
                }
                .help("メモの表示切替")
                .accessibilityLabel("メモの表示切替")

                Button(action: beginNewSession) {
                    Label("新しいセッション", systemImage: "plus")
                }
                .help("新しいセッション (⌘N)")
                .accessibilityLabel("新しいセッション")
            }
        }
        .sheet(isPresented: $showingNewSheet) {
            NewSessionSheet(
                settings: settings,
                folder: pendingFolder,
                onPickFolder: {
                    // Dismiss the sheet, run the panel, then re-present.
                    showingNewSheet = false
                    DispatchQueue.main.async {
                        pendingFolder = Self.runFolderPanel() ?? pendingFolder
                        showingNewSheet = true
                    }
                },
                onCreate: { dir in
                    showingNewSheet = false
                    withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
                        _ = store.add(workingDirectory: dir)
                    }
                },
                onCancel: { showingNewSheet = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiNewSession)) { _ in
            beginNewSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiClearBuffer)) { _ in
            TerminalRegistry.shared.clearFocused()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                notes.flush()
                store.persistNow()
            }
        }
    }

    /// `+` pressed → choose a folder (Cancel = "no folder"), then show the open-mode sheet.
    private func beginNewSession() {
        pendingFolder = Self.runFolderPanel()
        showingNewSheet = true
    }

    /// App-modal folder picker. Safe here because no SwiftUI sheet is presented yet.
    private static func runFolderPanel() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "セッションを開くフォルダ（キャンセルでホーム）"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
