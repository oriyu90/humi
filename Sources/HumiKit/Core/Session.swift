import Foundation

/// One terminal session shown as a tile. The heavy terminal view + child process live
/// in a `TerminalController` kept by `TerminalRegistry`, keyed by `id` — never in this value type.
struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    /// Directory the shell was started in. `nil` == "open as-is" (home / login default).
    var workingDirectory: String?
    /// Live title: OSC title from the shell, else the directory basename. Empty string
    /// means "no explicit title" — `displayTitle` substitutes the localized default.
    var title: String
    /// Index into `Hum.accents` — fixed at creation so a tile keeps its colour.
    var accentIndex: Int
    let createdAt: Date

    init(id: UUID = UUID(), workingDirectory: String?, accentIndex: Int) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.accentIndex = accentIndex
        self.createdAt = Date()
        self.title = Session.defaultTitle(for: workingDirectory)
    }

    /// Basename for a directory; empty string for "no directory" (see `title`).
    /// Pure and non-isolated — localization happens in `displayTitle`.
    static func defaultTitle(for dir: String?) -> String {
        guard let dir, !dir.isEmpty else { return "" }
        let name = (dir as NSString).lastPathComponent
        return name.isEmpty ? dir : name
    }

    /// True when `title` has never been set to anything explicit.
    var hasAutoTitle: Bool { title.isEmpty || title == Session.defaultTitle(for: workingDirectory) }

    @MainActor
    var displayTitle: String { title.isEmpty ? L("session.default_title") : title }

    @MainActor
    var displayDirectory: String {
        guard let workingDirectory else { return L("session.home") }
        return (workingDirectory as NSString).abbreviatingWithTildeInPath
    }
}
