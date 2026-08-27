import SwiftUI

/// On-disk shape of `sessions.json` from v1.2 on: the leaf registry plus the pane tree.
/// Pre-1.2 files are a bare top-level `[Session]` array — `SessionStore.restore` falls
/// back to decoding that and synthesizes a linear layout.
struct SessionsFile: Codable {
    var sessions: [Session]
    var layout: PaneNode?
}

/// The list of sessions. Owns persistence of the *list* (id + cwd + accent + title) and,
/// from v1.2, the `PaneNode` layout tree that arranges them; the live terminal/process for
/// each session lives in `TerminalRegistry`.
@MainActor
final class SessionStore: ObservableObject {
    static let fileName = "sessions.json"

    @Published private(set) var sessions: [Session] = []
    /// Recursive pane arrangement. `nil` == no sessions. `sessions` is the leaf registry
    /// (metadata); `layout` is the source of truth for structure.
    @Published private(set) var layout: PaneNode?
    /// Session expanded to fill the whole area, if any. `nil` == show the tile grid.
    @Published var maximizedID: UUID?
    /// Most recently created / interacted session — used only to scroll it into view.
    @Published var lastAddedID: UUID?
    /// Exit codes for sessions whose shell has terminated (observed by the tile).
    @Published private(set) var exitCodes: [UUID: Int32] = [:]

    private var nextAccent = 0
    private var persistWorkItem: DispatchWorkItem?

    init() {
        restore()
    }

    // MARK: Mutations

    /// Build a `Session` value from a profile without touching the store's collections.
    private func makeSession(workingDirectory: String?, profileID: UUID?) -> Session {
        let profile = ProfileStore.shared.profile(profileID)
        var session = Session(workingDirectory: workingDirectory,
                              accentIndex: profile?.colorIndex ?? nextAccent,
                              profileID: profileID,
                              logging: profile?.loggingDefault ?? false)
        if let profile { session.customTitle = profile.name }
        nextAccent += 1
        return session
    }

    @discardableResult
    func add(workingDirectory: String?, profileID: UUID? = nil) -> Session {
        let session = makeSession(workingDirectory: workingDirectory, profileID: profileID)
        sessions.append(session)
        if let last = layout?.leaves().last {
            // Append to the end of the arrangement — the v1.1 "one more column" behaviour.
            layout = layout?.insert(besideLeaf: last, axis: .horizontal, newLeaf: session.id, after: true)
        } else {
            layout = .leaf(session.id)
        }
        lastAddedID = session.id
        persist()
        return session
    }

    /// Create a session and place it next to `id` by splitting that pane along `axis`
    /// (⌘D / ⌘⇧D). Falls back to a bare leaf if there is no layout yet.
    @discardableResult
    func split(besideLeaf id: UUID, axis: Axis,
               workingDirectory: String?, profileID: UUID? = nil) -> Session {
        let session = makeSession(workingDirectory: workingDirectory, profileID: profileID)
        sessions.append(session)
        if let layout {
            self.layout = layout.insert(besideLeaf: id, axis: axis, newLeaf: session.id, after: true)
        } else {
            self.layout = .leaf(session.id)
        }
        lastAddedID = session.id
        persist()
        return session
    }

    func close(_ id: UUID) {
        TerminalRegistry.shared.terminate(id)
        sessions.removeAll { $0.id == id }
        layout = layout?.remove(leaf: id)
        exitCodes.removeValue(forKey: id)
        if maximizedID == id { maximizedID = nil }
        if lastAddedID == id { lastAddedID = layout?.leaves().last ?? sessions.last?.id }
        persist()
    }

    /// Whether closing `id` should prompt first, given the confirm-close pref.
    func closeNeedsConfirmation(_ id: UUID) -> Bool {
        switch AppSettings.shared.confirmClose {
        case .never:  return false
        case .always: return sessions.contains { $0.id == id }
        case .busy:   return TerminalRegistry.shared.existing(id)?.hasLiveForegroundChild ?? false
        }
    }

    // MARK: v1.1 per-session mutations

    private func mutate(_ id: UUID, _ body: (inout Session) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        body(&sessions[i])
        persist()
    }

    func setCustomTitle(_ id: UUID, _ name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        mutate(id) { $0.customTitle = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }
    func setAccentOverride(_ id: UUID, _ index: Int?) { mutate(id) { $0.accentOverride = index } }
    func setOnExit(_ id: UUID, _ v: OnExit) { mutate(id) { $0.onExit = v } }
    func setLogging(_ id: UUID, _ v: Bool) { mutate(id) { $0.logging = v } }

    /// Reorder the tile at `from` to `to` (drag-and-drop).
    func move(from: Int, to: Int) {
        guard sessions.indices.contains(from), to >= 0, to <= sessions.count, from != to else { return }
        let item = sessions.remove(at: from)
        sessions.insert(item, at: min(to, sessions.count))
        syncLinearLayoutAfterReorder()
        persist()
    }
    func move(id: UUID, before targetID: UUID) {
        guard let from = sessions.firstIndex(where: { $0.id == id }),
              let target = sessions.firstIndex(where: { $0.id == targetID }) else { return }
        move(from: from, to: from < target ? target - 1 : target)
    }

    // MARK: v1.2 pane-tree mutations

    /// Swap the positions of two panes in the tree.
    func swapPanes(_ a: UUID, _ b: UUID) {
        guard let layout else { return }
        self.layout = layout.swap(a, b)
        persist()
    }

    /// Drag a split divider: `dividerIndex` sits inside the split that directly holds `id`.
    func setPaneRatio(besideLeaf id: UUID, dividerIndex: Int, to r: CGFloat) {
        guard let layout else { return }
        self.layout = layout.setRatio(atSplitContaining: id, dividerIndex: dividerIndex, to: r)
        persist()
    }

    /// Reset every split so its children share the space equally (⌘⌥=).
    func equalizeSplits() {
        guard let layout else { return }
        self.layout = layout.equalized()
        persist()
    }

    /// Geometry-based directional focus target for the pane `id`, or `nil` at an edge.
    func paneNeighbor(of id: UUID, _ direction: Direction) -> UUID? {
        layout?.focusNeighbor(of: id, direction: direction)
    }

    func closeAll() {
        for s in sessions { TerminalRegistry.shared.terminate(s.id) }
        sessions.removeAll()
        layout = nil
        exitCodes.removeAll()
        maximizedID = nil
        lastAddedID = nil
        persist()
    }

    func markExited(_ id: UUID, code: Int32?) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        switch session.onExit {
        case .keep:
            exitCodes[id] = code ?? -1
        case .close:
            close(id)
        case .restart:
            exitCodes.removeValue(forKey: id)
            TerminalRegistry.shared.restart(session: session, settings: AppSettings.shared)
        }
    }

    /// Re-spawn the shell for a session whose process ended, in its original directory.
    func restart(_ id: UUID, settings: AppSettings) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        exitCodes.removeValue(forKey: id)
        TerminalRegistry.shared.restart(session: session, settings: settings)
    }

    func updateTitle(_ id: UUID, _ title: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = trimmed.isEmpty ? Session.defaultTitle(for: sessions[idx].workingDirectory) : trimmed
        guard sessions[idx].title != new else { return }
        sessions[idx].title = new
        persist()
    }

    func updateWorkingDirectory(_ id: UUID, _ dir: String?) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        guard sessions[idx].workingDirectory != dir else { return }
        let wasAutoTitle = sessions[idx].hasAutoTitle
        sessions[idx].workingDirectory = dir
        // Follow the cwd in the tile title, unless the shell (OSC 0/2) or the user
        // gave it a real title — then leave that alone. Home stays the localized default
        // (not the username) so an OSC-7 report of $HOME doesn't rename the tile.
        if wasAutoTitle {
            let atHome = dir.map { $0 == NSHomeDirectory() } ?? true
            sessions[idx].title = atHome ? "" : Session.defaultTitle(for: dir)
        }
        persist()
    }

    func toggleMaximize(_ id: UUID) {
        maximizedID = (maximizedID == id) ? nil : id
    }

    // MARK: Persistence (debounced; forced sync on teardown)

    private var fileSnapshot: SessionsFile { SessionsFile(sessions: sessions, layout: layout) }

    func persist() {
        persistWorkItem?.cancel()
        let snapshot = fileSnapshot
        let work = DispatchWorkItem { Persistence.encode(snapshot, to: SessionStore.fileName) }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func persistNow() {
        persistWorkItem?.cancel()
        Persistence.encode(fileSnapshot, to: SessionStore.fileName, sync: true)
    }

    // MARK: Restore + migration

    private func restore() {
        let file = Self.loadFile()
        var saved = file.sessions
        // Pre-1.1 sessions stored the literal "セッション" as the auto-title; normalize to
        // the empty sentinel so `displayTitle` localizes it.
        for i in saved.indices where saved[i].title == "セッション" { saved[i].title = "" }
        sessions = saved
        // Pre-1.2 files have no layout: build a single horizontal row from the saved order
        // so the arrangement matches what the user last saw. Then reconcile so the tree and
        // the leaf registry can never disagree (dropped/added leaves, decode drift).
        layout = Self.reconcile(file.layout ?? Self.linearLayout(for: saved), with: saved)
        nextAccent = (saved.map(\.accentIndex).max() ?? -1) + 1
        maximizedID = nil
        lastAddedID = layout?.leaves().last ?? saved.last?.id
    }

    /// Decode the new `{sessions, layout}` object, falling back to a bare `[Session]` array.
    private static func loadFile() -> SessionsFile {
        guard let data = Persistence.readData(fileName) else { return SessionsFile(sessions: [], layout: nil) }
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(SessionsFile.self, from: data) { return file }
        if let array = try? decoder.decode([Session].self, from: data) {
            return SessionsFile(sessions: array, layout: nil)
        }
        return SessionsFile(sessions: [], layout: nil)
    }

    /// A single horizontal row of equal-width panes, matching the pre-1.2 grid.
    static func linearLayout(for sessions: [Session]) -> PaneNode? {
        let ids = sessions.map(\.id)
        guard !ids.isEmpty else { return nil }
        if ids.count == 1 { return .leaf(ids[0]) }
        let even = Array(repeating: 1 / CGFloat(ids.count), count: ids.count)
        return .split(axis: .horizontal, children: ids.map { .leaf($0) }, ratios: even)
    }

    /// Force `tree` to cover exactly the ids in `sessions`: prune leaves with no session,
    /// append sessions with no leaf, normalize. Fail-safe against a corrupt layout.
    static func reconcile(_ tree: PaneNode?, with sessions: [Session]) -> PaneNode? {
        let valid = Set(sessions.map(\.id))
        var result = tree
        for id in result?.leaves() ?? [] where !valid.contains(id) {
            result = result?.remove(leaf: id)
        }
        var present = Set(result?.leaves() ?? [])
        for session in sessions where !present.contains(session.id) {
            if let last = result?.leaves().last {
                result = result?.insert(besideLeaf: last, axis: .horizontal, newLeaf: session.id, after: true)
            } else {
                result = .leaf(session.id)
            }
            present.insert(session.id)
        }
        return result?.normalized()
    }

    /// After a v1.1-style array reorder, keep a still-flat layout in step with the new
    /// order. A layout with real splits (`depth > 1`) is left untouched.
    private func syncLinearLayoutAfterReorder() {
        guard let current = layout else {
            layout = Self.linearLayout(for: sessions)
            return
        }
        guard current.depth <= 1, Set(current.leaves()) == Set(sessions.map(\.id)) else { return }
        layout = Self.linearLayout(for: sessions)
    }
}
