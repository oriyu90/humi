import Foundation

/// What happens to a tile when its shell process ends.
enum OnExit: String, Codable, CaseIterable, Identifiable, Sendable {
    case keep      // leave the exited tile in place with a restart button (current behaviour)
    case restart   // re-spawn immediately
    case close     // remove the tile
    var id: String { rawValue }
}

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

    // MARK: v1.1 additions — all optional so pre-1.1 `sessions.json` still decodes.

    /// User-set name; overrides `title` in `displayTitle` when present.
    var customTitle: String?
    /// Per-session accent override (index into `Hum.accents`); falls back to `accentIndex`.
    var accentOverride: Int?
    /// Behaviour when the shell exits.
    var onExit: OnExit
    /// Profile this session was created from (drives shell/env/theme/startup on restore).
    var profileID: UUID?
    /// Whether this session's output is being written to a log file.
    var logging: Bool

    init(id: UUID = UUID(),
         workingDirectory: String?,
         accentIndex: Int,
         profileID: UUID? = nil,
         onExit: OnExit = .keep,
         logging: Bool = false) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.accentIndex = accentIndex
        self.createdAt = Date()
        self.title = Session.defaultTitle(for: workingDirectory)
        self.customTitle = nil
        self.accentOverride = nil
        self.onExit = onExit
        self.profileID = profileID
        self.logging = logging
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory)
        title = try c.decode(String.self, forKey: .title)
        accentIndex = try c.decode(Int.self, forKey: .accentIndex)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        customTitle = try c.decodeIfPresent(String.self, forKey: .customTitle)
        accentOverride = try c.decodeIfPresent(Int.self, forKey: .accentOverride)
        onExit = try c.decodeIfPresent(OnExit.self, forKey: .onExit) ?? .keep
        profileID = try c.decodeIfPresent(UUID.self, forKey: .profileID)
        logging = try c.decodeIfPresent(Bool.self, forKey: .logging) ?? false
    }

    /// Basename for a directory; empty string for "no directory" (see `title`).
    /// Pure and non-isolated — localization happens in `displayTitle`.
    static func defaultTitle(for dir: String?) -> String {
        guard let dir, !dir.isEmpty else { return "" }
        let name = (dir as NSString).lastPathComponent
        return name.isEmpty ? dir : name
    }

    /// True when neither the shell/user nor a custom name has set an explicit title.
    var hasAutoTitle: Bool {
        (customTitle?.isEmpty ?? true) && (title.isEmpty || title == Session.defaultTitle(for: workingDirectory))
    }

    /// Effective accent index (per-session override wins).
    var effectiveAccent: Int { accentOverride ?? accentIndex }

    @MainActor
    var displayTitle: String {
        if let custom = customTitle, !custom.isEmpty { return custom }
        return title.isEmpty ? L("session.default_title") : title
    }

    @MainActor
    var displayDirectory: String {
        guard let workingDirectory else { return L("session.home") }
        return (workingDirectory as NSString).abbreviatingWithTildeInPath
    }
}
