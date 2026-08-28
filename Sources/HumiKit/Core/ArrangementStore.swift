import CoreGraphics
import Foundation

/// Named window arrangements, persisted to `arrangements.json`. A snapshot captures the
/// current pane tree, per-leaf session metadata, and the window frame; restoring rebuilds
/// fresh sessions and hands `SessionStore` a ready-made layout.
@MainActor
final class ArrangementStore: ObservableObject {
    static let shared = ArrangementStore()
    static let fileName = "arrangements.json"

    @Published private(set) var arrangements: [Arrangement] = []

    private struct Disk: Codable { var arrangements: [Arrangement] }

    private init() {
        if let d = Persistence.decode(Disk.self, from: Self.fileName) {
            arrangements = d.arrangements
        }
    }

    func arrangement(_ id: UUID) -> Arrangement? { arrangements.first { $0.id == id } }

    // MARK: snapshot / restore

    /// Build an arrangement from the live session state. Returns `nil` if there's nothing
    /// to save. Leaves not present in `layout` are ignored.
    func snapshot(name: String, layout: PaneNode?, sessions: [Session],
                         windowFrame: CGRect) -> Arrangement? {
        guard let layout else { return nil }
        let inTree = Set(layout.leaves())
        let leaves = sessions.filter { inTree.contains($0.id) }.map { s in
            Arrangement.LeafSpec(localID: s.id,
                                 workingDirectory: s.workingDirectory,
                                 profileID: s.profileID,
                                 customTitle: s.customTitle,
                                 accentIndex: s.accentIndex,
                                 accentOverride: s.accentOverride,
                                 onExit: s.onExit,
                                 logging: s.logging)
        }
        guard !leaves.isEmpty else { return nil }
        return Arrangement(name: name, windowFrame: windowFrame, layout: layout, leaves: leaves)
    }

    /// Turn a saved arrangement into fresh sessions + a layout that references them.
    /// Only specs that actually appear in the layout become sessions — a hand-edited
    /// `.humiarrangement` can't smuggle in extra panes.
    func materialize(_ arrangement: Arrangement) -> (sessions: [Session], layout: PaneNode) {
        let inTree = Set(arrangement.layout.leaves())
        var idMap: [UUID: UUID] = [:]
        var sessions: [Session] = []
        for spec in arrangement.leaves where inTree.contains(spec.localID) {
            var s = Session(workingDirectory: spec.workingDirectory,
                            accentIndex: spec.accentIndex,
                            profileID: spec.profileID,
                            onExit: spec.onExit,
                            logging: spec.logging)
            s.customTitle = spec.customTitle
            s.accentOverride = spec.accentOverride
            idMap[spec.localID] = s.id
            sessions.append(s)
        }
        let layout = arrangement.layout.remappingLeaves(idMap).normalized()
        // Drop any leaves the spec list didn't cover.
        let valid = Set(sessions.map(\.id))
        var pruned: PaneNode? = layout
        for id in layout.leaves() where !valid.contains(id) { pruned = pruned?.remove(leaf: id) }
        return (sessions, pruned ?? layout)
    }

    // MARK: CRUD

    func add(_ arrangement: Arrangement) {
        if let i = arrangements.firstIndex(where: { $0.name == arrangement.name }) {
            arrangements[i] = arrangement          // overwrite same-named
        } else {
            arrangements.append(arrangement)
        }
        persist()
    }

    func delete(id: UUID) {
        arrangements.removeAll { $0.id == id }
        persist()
    }

    func rename(id: UUID, to name: String) {
        guard let i = arrangements.firstIndex(where: { $0.id == id }) else { return }
        arrangements[i].name = name
        persist()
    }

    private func persist() {
        Persistence.encode(Disk(arrangements: arrangements), to: Self.fileName)
        objectWillChange.send()
    }

    // MARK: .humiarrangement import / export

    func export(_ arrangement: Arrangement, to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(arrangement).write(to: url, options: .atomic)
    }

    @discardableResult
    func importArrangement(from url: URL) -> Arrangement? {
        guard let data = try? Data(contentsOf: url),
              var a = try? JSONDecoder().decode(Arrangement.self, from: data) else { return nil }
        a.id = UUID()
        if arrangements.contains(where: { $0.name == a.name }) { a.name += " (imported)" }
        arrangements.append(a)
        persist()
        return a
    }
}
