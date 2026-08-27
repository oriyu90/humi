import SwiftUI
import Combine

/// Markdown scratch text for the sidebar. Persisted to notes.md, debounced 0.5s,
/// atomic write. Survives app restarts (common-rules / spec requirement).
@MainActor
public final class NotesStore: ObservableObject {
    public static let shared = NotesStore()
    static let fileName = "notes.md"

    @Published var text: String {
        didSet { scheduleSave() }
    }

    private var saveWorkItem: DispatchWorkItem?

    private init() {
        self.text = Persistence.readString(NotesStore.fileName) ?? L("notes.placeholder")
    }

    @MainActor static var placeholder: String { L("notes.placeholder") }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = text
        let work = DispatchWorkItem { Persistence.writeString(snapshot, to: NotesStore.fileName) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Force a synchronous flush (called on resign-active / app terminate).
    public func flush() {
        saveWorkItem?.cancel()
        Persistence.writeStringSync(text, to: NotesStore.fileName)
    }
}
