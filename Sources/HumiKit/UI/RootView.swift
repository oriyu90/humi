import SwiftUI
import AppKit

public extension Notification.Name {
    /// Posted by the ⌘N command; RootView opens the new-session flow.
    static let humiNewSession = Notification.Name("humi.newSession")
    /// Posted by the ⌘K command; clears the focused session's scrollback.
    static let humiClearBuffer = Notification.Name("humi.clearBuffer")
    static let humiFind = Notification.Name("humi.find")
    static let humiFontIn = Notification.Name("humi.fontIn")
    static let humiFontOut = Notification.Name("humi.fontOut")
    static let humiFontReset = Notification.Name("humi.fontReset")
    static let humiNextTile = Notification.Name("humi.nextTile")
    static let humiPrevTile = Notification.Name("humi.prevTile")
}

public struct RootView: View {
    public init() {}

    @StateObject private var store = SessionStore()
    @ObservedObject private var notes = NotesStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var themes = ThemeStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    @State private var showingNewSheet = false
    @State private var pendingFolder: String?
    @State private var searchVisible = false
    @Environment(\.scenePhase) private var scenePhase

    public var body: some View {
        HSplitView {
            SessionGridView(store: store, settings: settings, onNew: beginNewSession)
                .frame(minWidth: 420)
                .overlay(alignment: .top) {
                    if searchVisible {
                        SearchBar(isPresented: $searchVisible)
                            .padding(.top, Hum.Space.sm)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

            if settings.notesVisible {
                NotesSidebarView(notes: notes, settings: settings)
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 520)
            }
        }
        .background(Hum.paper2)
        .environment(\.locale, loc.locale)
        .preferredColorScheme(themes.resolvedTheme.appAppearance == .dark ? .dark : .light)
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
                .help(L("toolbar.toggle_notes"))
                .accessibilityLabel(L("toolbar.toggle_notes"))

                if !profiles.profiles.isEmpty {
                    Menu {
                        ForEach(profiles.profiles) { p in
                            Button {
                                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
                                    _ = store.add(workingDirectory: p.cwd, profileID: p.id)
                                }
                            } label: { Label(p.name, systemImage: p.icon) }
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .help(L("launcher.title"))
                }

                Button(action: beginNewSession) {
                    Label(L("toolbar.new_session"), systemImage: "plus")
                }
                .help(L("toolbar.new_session.help"))
                .accessibilityLabel(L("toolbar.new_session"))
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
                onCreate: { dir, pid in
                    showingNewSheet = false
                    withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
                        _ = store.add(workingDirectory: dir, profileID: pid)
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
        .onReceive(NotificationCenter.default.publisher(for: .humiFind)) { _ in
            withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { searchVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiFontIn)) { _ in
            settings.fontSize = min(settings.fontSize + 1, 28)
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiFontOut)) { _ in
            settings.fontSize = max(settings.fontSize - 1, 9)
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiFontReset)) { _ in
            settings.fontSize = themes.resolvedTheme.fontSize
        }
        .onReceive(NotificationCenter.default.publisher(for: .humiNextTile)) { _ in focusTile(offset: 1) }
        .onReceive(NotificationCenter.default.publisher(for: .humiPrevTile)) { _ in focusTile(offset: -1) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                notes.flush()
                store.persistNow()
            }
        }
    }

    /// Move keyboard focus to the tile `offset` positions from the focused one.
    private func focusTile(offset: Int) {
        let ids = store.sessions.map(\.id)
        guard !ids.isEmpty else { return }
        let currentID = TerminalRegistry.shared.focusedController()?.sessionID
        let currentIndex = currentID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let nextIndex = (currentIndex + offset + ids.count) % ids.count
        guard let view = TerminalRegistry.shared.existing(ids[nextIndex])?.terminalView,
              let window = view.window else { return }
        window.makeFirstResponder(view)
    }

    /// `+` pressed → choose a folder (Cancel = "no folder"), then show the open-mode sheet.
    private func beginNewSession() {
        pendingFolder = Self.runFolderPanel()
        showingNewSheet = true
    }

    /// App-modal folder picker. Safe here because no SwiftUI sheet is presented yet.
    @MainActor
    private static func runFolderPanel() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("panel.choose")
        panel.message = L("panel.message")
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
