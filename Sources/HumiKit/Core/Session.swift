import Foundation

/// One terminal session shown as a tile. The heavy terminal view + child process live
/// in a `TerminalController` kept by `TerminalRegistry`, keyed by `id` — never in this value type.
struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    /// Directory the shell was started in. `nil` == "open as-is" (home / login default).
    var workingDirectory: String?
    /// Live title: OSC title from the shell, else the directory basename, else "セッション".
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

    static func defaultTitle(for dir: String?) -> String {
        guard let dir, !dir.isEmpty else { return "セッション" }
        let name = (dir as NSString).lastPathComponent
        return name.isEmpty ? dir : name
    }

    var displayDirectory: String {
        guard let workingDirectory else { return "ホーム" }
        return (workingDirectory as NSString).abbreviatingWithTildeInPath
    }
}
