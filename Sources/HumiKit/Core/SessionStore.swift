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

    func closeAll() {
        for s in sessions { TerminalRegistry.shared.terminate(s.id) }
        sessions.removeAll()
        exitCodes.removeAll()
        maximizedID = nil
        lastAddedID = nil
        persist()
    }

    func markExited(_ id: UUID, code: Int32?) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        exitCodes[id] = code ?? -1
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
        let wasAutoTitle = sessions[idx].title == Session.defaultTitle(for: sessions[idx].workingDirectory)
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
        let saved = Persistence.decode([Session].self, from: SessionStore.fileName) ?? []
        sessions = saved
        nextAccent = (saved.map(\.accentIndex).max() ?? -1) + 1
        maximizedID = nil
        lastAddedID = saved.last?.id
    }
}
