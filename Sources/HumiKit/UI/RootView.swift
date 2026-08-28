import SwiftUI
import AppKit
import Combine

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
    static let humiCloseTile = Notification.Name("humi.closeTile")
    static let humiRestartTile = Notification.Name("humi.restartTile")
    static let humiMaximizeTile = Notification.Name("humi.maximizeTile")
    static let humiToggleNotes = Notification.Name("humi.toggleNotes")
    static let humiProfileLauncher = Notification.Name("humi.profileLauncher")
    // v1.2 — arrangements (menu-driven; object carries the arrangement UUID on restore)
    static let humiSaveArrangement = Notification.Name("humi.saveArrangement")
    static let humiRestoreArrangement = Notification.Name("humi.restoreArrangement")
    // v1.2 — pane tree
    static let humiSplitH = Notification.Name("humi.splitH")
    static let humiSplitV = Notification.Name("humi.splitV")
    static let humiFocusPaneLeft = Notification.Name("humi.focusPaneLeft")
    static let humiFocusPaneRight = Notification.Name("humi.focusPaneRight")
    static let humiFocusPaneUp = Notification.Name("humi.focusPaneUp")
    static let humiFocusPaneDown = Notification.Name("humi.focusPaneDown")
    static let humiEqualizeSplits = Notification.Name("humi.equalizeSplits")
    /// Posted (object: session UUID) when a terminal becomes the working terminal.
    /// Not a user action — drives the pane focus ring, so it's kept out of `humiAllActions`.
    static let humiFocusChanged = Notification.Name("humi.focusChanged")

    static let humiAllActions: [Notification.Name] = [
        .humiNewSession, .humiClearBuffer, .humiFind, .humiFontIn, .humiFontOut, .humiFontReset,
        .humiNextTile, .humiPrevTile, .humiCloseTile, .humiRestartTile, .humiMaximizeTile,
        .humiToggleNotes, .humiProfileLauncher,
        .humiSplitH, .humiSplitV, .humiFocusPaneLeft, .humiFocusPaneRight,
        .humiFocusPaneUp, .humiFocusPaneDown, .humiEqualizeSplits,
        .humiSaveArrangement, .humiRestoreArrangement,
    ]
}

public struct RootView: View {
    public init() {}

    @StateObject private var store = SessionStore()
    @ObservedObject private var notes = NotesStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var themes = ThemeStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var arrangements = ArrangementStore.shared

    @State private var showingNewSheet = false
    @State private var pendingFolder: String?
    @State private var searchVisible = false
    @State private var savingArrangement = false
    @State private var restoringArrangement = false
    @State private var arrangementName = ""
    @Environment(\.scenePhase) private var scenePhase

    public var body: some View {
        HSplitView {
            PaneTreeView(store: store, settings: settings, onNew: beginNewSession)
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
        .onReceive(actionPublisher) { note in handle(note) }
        .onReceive(NotificationCenter.default.publisher(for: HumiNotifier.focusRequest)) { note in
            if let id = note.object as? UUID { focusSpecificPane(id) }
        }
        .alert(L("arrangement.save.title"), isPresented: $savingArrangement) {
            TextField(L("arrangement.save.prompt"), text: $arrangementName)
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("arrangement.save")) { saveArrangement(named: arrangementName) }
        }
        .confirmationDialog(L("arrangement.restore"), isPresented: $restoringArrangement,
                            titleVisibility: .visible) {
            if arrangements.arrangements.isEmpty {
                Text(L("arrangement.none"))
            } else {
                ForEach(arrangements.arrangements) { a in
                    Button(a.name) { restoreArrangement(a) }
                }
            }
            Button(L("common.cancel"), role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                notes.flush()
                store.persistNow()
            }
        }
    }

    private var actionPublisher: AnyPublisher<Notification, Never> {
        Publishers.MergeMany(
            Notification.Name.humiAllActions.map { NotificationCenter.default.publisher(for: $0) }
        ).eraseToAnyPublisher()
    }

    private func handle(_ note: Notification) {
        let name = note.name
        let focusedID = TerminalRegistry.shared.focusedController()?.sessionID
        switch name {
        case .humiNewSession:  beginNewSession()
        case .humiClearBuffer: TerminalRegistry.shared.clearFocused()
        case .humiFind:        withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { searchVisible = true }
        case .humiFontIn:      settings.fontSize = min(settings.fontSize + 1, 28)
        case .humiFontOut:     settings.fontSize = max(settings.fontSize - 1, 9)
        case .humiFontReset:   settings.fontSize = themes.resolvedTheme.fontSize
        case .humiNextTile:    focusTile(offset: 1)
        case .humiPrevTile:    focusTile(offset: -1)
        case .humiToggleNotes:
            withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { settings.notesVisible.toggle() }
        case .humiCloseTile:
            if let id = focusedID {
                if store.closeNeedsConfirmation(id) { NSSound.beep() } else { store.close(id) }
            }
        case .humiRestartTile:
            if let id = focusedID { store.restart(id, settings: settings) }
        case .humiMaximizeTile:
            if let id = focusedID {
                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { store.toggleMaximize(id) }
            }
        case .humiProfileLauncher:
            if let p = profiles.defaultProfile ?? profiles.profiles.first {
                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
                    _ = store.add(workingDirectory: p.cwd, profileID: p.id)
                }
            } else { beginNewSession() }
        case .humiSplitH: splitFocused(.horizontal, focusedID: focusedID)
        case .humiSplitV: splitFocused(.vertical, focusedID: focusedID)
        case .humiFocusPaneLeft:  focusPane(.left)
        case .humiFocusPaneRight: focusPane(.right)
        case .humiFocusPaneUp:    focusPane(.up)
        case .humiFocusPaneDown:  focusPane(.down)
        case .humiEqualizeSplits:
            withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { store.equalizeSplits() }
        case .humiSaveArrangement:
            arrangementName = ""
            savingArrangement = true
        case .humiRestoreArrangement:
            if let id = note.object as? UUID, let a = arrangements.arrangement(id) {
                restoreArrangement(a)
            } else {
                restoringArrangement = true
            }
        default: break
        }
    }

    // MARK: arrangements

    private func saveArrangement(named raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let frame = NSApp.keyWindow?.frame ?? .zero
        guard let a = arrangements.snapshot(name: name, layout: store.layout,
                                            sessions: store.sessions, windowFrame: frame) else { return }
        arrangements.add(a)
    }

    private func restoreArrangement(_ a: Arrangement) {
        let (sessions, layout) = arrangements.materialize(a)
        withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
            store.load(sessions: sessions, layout: layout)
        }
        if a.windowFrame != .zero {
            NSApp.keyWindow?.setFrame(a.windowFrame, display: true, animate: true)
        }
    }

    /// ⌘D / ⌘⇧D — split the focused pane, opening the new shell in the same directory.
    private func splitFocused(_ axis: Axis, focusedID: UUID?) {
        guard let id = focusedID ?? store.layout?.leaves().last,
              let source = store.sessions.first(where: { $0.id == id }) else {
            beginNewSession()
            return
        }
        withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
            _ = store.split(besideLeaf: id, axis: axis,
                            workingDirectory: source.workingDirectory, profileID: source.profileID)
        }
    }

    /// Make a specific pane first responder (notification tap).
    private func focusSpecificPane(_ id: UUID) {
        guard let view = TerminalRegistry.shared.existing(id)?.terminalView,
              let window = view.window else { return }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        TerminalRegistry.shared.noteFocused(id)
        NotificationCenter.default.post(name: .humiFocusChanged, object: id)
    }

    /// ⌘⌃arrow — move keyboard focus to the neighbouring pane in that direction.
    private func focusPane(_ direction: Direction) {
        guard let current = TerminalRegistry.shared.focusedController()?.sessionID,
              let target = store.paneNeighbor(of: current, direction),
              let view = TerminalRegistry.shared.existing(target)?.terminalView,
              let window = view.window else { return }
        window.makeFirstResponder(view)
        TerminalRegistry.shared.noteFocused(target)
        NotificationCenter.default.post(name: .humiFocusChanged, object: target)
    }

    /// Move keyboard focus to the tile `offset` positions from the focused one,
    /// walking panes in visual (layout) order.
    private func focusTile(offset: Int) {
        let ids = store.layout?.leaves() ?? store.sessions.map(\.id)
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
