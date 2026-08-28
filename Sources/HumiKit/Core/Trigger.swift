import Foundation

/// What a matched output line does. Kept flat (kind + colorIndex) so `Codable` is trivial.
struct TriggerAction: Codable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case notify, bell, color
        var id: String { rawValue }
    }
    var kind: Kind
    var colorIndex: Int

    init(kind: Kind, colorIndex: Int = 0) {
        self.kind = kind
        self.colorIndex = colorIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .notify
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
    }
}

/// A regex-on-output rule (iTerm2 "Triggers", trimmed down). Stored globally in
/// `AppSettings.triggers` as JSON.
struct Trigger: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var pattern: String
    var action: TriggerAction
    var enabled: Bool

    init(id: UUID = UUID(), pattern: String, action: TriggerAction, enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.action = action
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        action = try c.decodeIfPresent(TriggerAction.self, forKey: .action)
            ?? TriggerAction(kind: .notify)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Compiles a trigger list once and matches lines against it. Disabled rows, empty
/// patterns, and patterns that don't compile are dropped so `isEmpty` is a reliable
/// "nothing to watch" signal.
struct TriggerEngine {
    private let compiled: [(trigger: Trigger, regex: NSRegularExpression)]

    init(_ triggers: [Trigger]) {
        compiled = triggers.compactMap { t in
            guard t.enabled, !t.pattern.isEmpty,
                  let re = try? NSRegularExpression(pattern: t.pattern) else { return nil }
            return (t, re)
        }
    }

    var isEmpty: Bool { compiled.isEmpty }

    /// Every trigger whose pattern occurs in `line`, in declaration order.
    func matches(_ line: String) -> [Trigger] {
        let range = NSRange(line.startIndex..., in: line)
        return compiled
            .filter { $0.regex.firstMatch(in: line, options: [], range: range) != nil }
            .map(\.trigger)
    }
}
