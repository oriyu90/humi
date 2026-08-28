import CoreGraphics
import Foundation

/// A saved window arrangement: the pane tree plus enough per-leaf metadata to
/// recreate every session. Leaf ids inside `layout` are local to the arrangement —
/// `ArrangementStore.materialize` swaps in fresh UUIDs on restore so a restored
/// arrangement never collides with the sessions already on disk.
struct Arrangement: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var windowFrame: CGRect
    var layout: PaneNode
    var leaves: [LeafSpec]

    init(id: UUID = UUID(), name: String, windowFrame: CGRect,
                layout: PaneNode, leaves: [LeafSpec]) {
        self.id = id
        self.name = name
        self.windowFrame = windowFrame
        self.layout = layout
        self.leaves = leaves
    }

    /// One pane's worth of restorable session metadata.
    struct LeafSpec: Codable, Equatable, Sendable {
        var localID: UUID          // matches a `.leaf(localID)` in `layout`
        var workingDirectory: String?
        var profileID: UUID?
        var customTitle: String?
        var accentIndex: Int
        var accentOverride: Int?
        var onExit: OnExit
        var logging: Bool

        init(localID: UUID, workingDirectory: String?, profileID: UUID?,
                    customTitle: String?, accentIndex: Int, accentOverride: Int?,
                    onExit: OnExit, logging: Bool) {
            self.localID = localID
            self.workingDirectory = workingDirectory
            self.profileID = profileID
            self.customTitle = customTitle
            self.accentIndex = accentIndex
            self.accentOverride = accentOverride
            self.onExit = onExit
            self.logging = logging
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            localID = try c.decode(UUID.self, forKey: .localID)
            workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory)
            profileID = try c.decodeIfPresent(UUID.self, forKey: .profileID)
            customTitle = try c.decodeIfPresent(String.self, forKey: .customTitle)
            accentIndex = try c.decodeIfPresent(Int.self, forKey: .accentIndex) ?? 0
            accentOverride = try c.decodeIfPresent(Int.self, forKey: .accentOverride)
            onExit = try c.decodeIfPresent(OnExit.self, forKey: .onExit) ?? .keep
            logging = try c.decodeIfPresent(Bool.self, forKey: .logging) ?? false
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Arrangement"
        windowFrame = try c.decodeIfPresent(CGRect.self, forKey: .windowFrame) ?? .zero
        layout = try c.decode(PaneNode.self, forKey: .layout)
        leaves = try c.decodeIfPresent([LeafSpec].self, forKey: .leaves) ?? []
    }
}
