import SwiftUI

/// The list of sessions. Owns persistence of the *list* (id + cwd + accent + title);
/// the live terminal/process for each session lives in `TerminalRegistry`.
@MainActor
final class SessionStore: ObservableObject {
    static let fileName = "sessions.json"

    @Published private(set) var sessions: [Session] = []
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

    @discardableResult
    func add(workingDirectory: String?) -> Session {
        let session = Session(workingDirectory: workingDirectory, accentIndex: nextAccent)
        nextAccent += 1
        sessions.append(session)
        lastAddedID = session.id
        persist()
        return session
    }

    func close(_ id: UUID) {
        TerminalRegistry.shared.terminate(id)
        sessions.removeAll { $0.id == id }
        exitCodes.removeValue(forKey: id)
        if maximizedID == id { maximizedID = nil }
        if lastAddedID == id { lastAddedID = sessions.last?.id }
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
        persist()
    }
    func move(id: UUID, before targetID: UUID) {
        guard let from = sessions.firstIndex(where: { $0.id == id }),
              let target = sessions.firstIndex(where: { $0.id == targetID }) else { return }
        move(from: from, to: from < target ? target - 1 : target)
    }

    func closeAll() {
        for s in sessions { TerminalRegistry.shared.terminate(s.id) }
        sessions.removeAll()
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
        // gave it a real title — then leave that alone.
        if wasAutoTitle {
            sessions[idx].title = Session.defaultTitle(for: dir)
        }
        persist()
    }

    func toggleMaximize(_ id: UUID) {
        maximizedID = (maximizedID == id) ? nil : id
    }

    // MARK: Persistence (debounced; forced sync on teardown)

    func persist() {
        persistWorkItem?.cancel()
        let snapshot = sessions
        let work = DispatchWorkItem { Persistence.encode(snapshot, to: SessionStore.fileName) }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func persistNow() {
        persistWorkItem?.cancel()
        Persistence.encode(sessions, to: SessionStore.fileName, sync: true)
    }

    private func restore() {
        var saved = Persistence.decode([Session].self, from: SessionStore.fileName) ?? []
        // Pre-1.1 sessions stored the literal "セッション" as the auto-title; normalize to
        // the empty sentinel so `displayTitle` localizes it.
        for i in saved.indices where saved[i].title == "セッション" { saved[i].title = "" }
        sessions = saved
        nextAccent = (saved.map(\.accentIndex).max() ?? -1) + 1
        maximizedID = nil
        lastAddedID = saved.last?.id
    }
}
