import SwiftUI
import Combine

/// One named Markdown note — a tab in the notes sidebar.
///
/// `id` is kept stable across export/import so the same note synced between two
/// machines updates in place instead of piling up duplicates (see `NotesStore.merge`).
public struct NoteDoc: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var createdAt: Double
    public var modifiedAt: Double

    public init(id: UUID = UUID(), title: String, text: String = "",
                createdAt: Double = Date().timeIntervalSinceReferenceDate,
                modifiedAt: Double = Date().timeIntervalSinceReferenceDate) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        let now = Date().timeIntervalSinceReferenceDate
        createdAt = try c.decodeIfPresent(Double.self, forKey: .createdAt) ?? now
        modifiedAt = try c.decodeIfPresent(Double.self, forKey: .modifiedAt) ?? now
    }
}

/// The notes sidebar's documents. A list of `NoteDoc` tabs plus which one is shown
/// (`activeID == nil` → the Home tab, i.e. the note list). Persisted to `notes.json`,
/// debounced 0.5 s, atomic write. Migrates a pre-1.4 `notes.md` on first launch.
@MainActor
public final class NotesStore: ObservableObject {
    public static let shared = NotesStore()
    static let fileName = "notes.json"
    static let legacyFileName = "notes.md"

    @Published public private(set) var notes: [NoteDoc] = []

    /// `nil` = the Home tab (the note list). Otherwise the shown note's id.
    @Published public var activeID: UUID? {
        didSet { if activeID != oldValue { scheduleSave() } }
    }

    private var saveWorkItem: DispatchWorkItem?

    struct Disk: Codable { var notes: [NoteDoc]; var activeID: UUID? }

    private init() {
        if let d = Persistence.decode(Disk.self, from: Self.fileName), !d.notes.isEmpty {
            notes = d.notes
            activeID = d.activeID.flatMap { id in d.notes.contains { $0.id == id } ? id : nil }
            return
        }

        // Pre-1.4 migration: one note carrying the old single-buffer text.
        if let legacy = Persistence.readString(Self.legacyFileName),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           legacy != L("notes.placeholder") {
            let n = NoteDoc(title: Self.defaultTitle(existing: []), text: legacy)
            notes = [n]
            activeID = n.id
        } else {
            // Fresh install: seed one note with the help placeholder so it isn't blank.
            let n = NoteDoc(title: Self.defaultTitle(existing: []), text: L("notes.placeholder"))
            notes = [n]
            activeID = n.id
        }
        scheduleSave()
    }

    // MARK: lookup

    public func note(_ id: UUID?) -> NoteDoc? {
        guard let id else { return nil }
        return notes.first { $0.id == id }
    }

    public var activeNote: NoteDoc? { note(activeID) }

    /// A binding to one note's body. Writes go through `updateText` (timestamp + save).
    public func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.notes.first(where: { $0.id == id })?.text ?? "" },
            set: { [weak self] in self?.updateText(id, $0) }
        )
    }

    // MARK: mutations

    @discardableResult
    public func newNote() -> NoteDoc {
        let n = NoteDoc(title: Self.defaultTitle(existing: notes), text: "")
        notes.append(n)
        activeID = n.id
        scheduleSave()
        return n
    }

    public func rename(_ id: UUID, to raw: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != notes[i].title else { return }
        notes[i].title = name
        notes[i].modifiedAt = Date().timeIntervalSinceReferenceDate
        scheduleSave()
    }

    public func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if activeID == id { activeID = nil }   // fall back to the Home tab
        scheduleSave()
    }

    public func updateText(_ id: UUID, _ text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        notes[i].modifiedAt = Date().timeIntervalSinceReferenceDate
        scheduleSave()
    }

    public func open(_ id: UUID?) {
        activeID = id.flatMap { id in notes.contains { $0.id == id } ? id : nil }
    }

    // MARK: import merge

    /// Merge imported notes into the list. Per spec:
    /// - existing note with the **same id and title** → the imported one replaces it
    ///   (imported wins; keeps its slot).
    /// - id collision with a **different** title → the import gets a fresh id, appended.
    /// - otherwise → appended, keeping its id (so a later re-import updates in place).
    /// Returns (added, replaced).
    @discardableResult
    public func merge(imported incoming: [NoteDoc]) -> (added: Int, replaced: Int) {
        var added = 0, replaced = 0
        for var doc in incoming {
            if let i = notes.firstIndex(where: { $0.id == doc.id && $0.title == doc.title }) {
                notes[i] = doc
                replaced += 1
            } else if notes.contains(where: { $0.id == doc.id }) {
                doc.id = UUID()
                notes.append(doc)
                added += 1
            } else {
                notes.append(doc)
                added += 1
            }
        }
        if !incoming.isEmpty { scheduleSave() }
        return (added, replaced)
    }

    // MARK: naming

    /// "Notes 1", "Notes 2", … — lowest free index (label from `notes.title`).
    static func defaultTitle(existing: [NoteDoc]) -> String {
        let base = L("notes.title")
        let taken = Set(existing.map(\.title))
        var n = 1
        while taken.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = Disk(notes: notes, activeID: activeID)
        let work = DispatchWorkItem { Persistence.encode(snapshot, to: NotesStore.fileName) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Force a synchronous flush (resign-active / app terminate).
    public func flush() {
        saveWorkItem?.cancel()
        Persistence.encode(Disk(notes: notes, activeID: activeID), to: NotesStore.fileName, sync: true)
    }
}
