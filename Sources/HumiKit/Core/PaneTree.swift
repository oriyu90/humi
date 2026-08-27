import CoreGraphics
import Foundation

/// Orientation of a split. `horizontal` lays its children out left-to-right (divides the
/// x axis); `vertical` stacks them top-to-bottom (divides the y axis).
enum Axis: String, Codable, Sendable {
    case horizontal
    case vertical
}

/// Compass direction for keyboard focus movement between panes.
enum Direction: Sendable {
    case left, right, up, down
}

/// The recursive pane layout that replaces v1.1's flat `[Session]` grid.
///
/// A `.leaf` carries a session id; a `.split` carries an axis, an ordered list of child
/// nodes, and a matching list of ratios (each in `(0, 1)`, summing to 1) giving each child's
/// fraction of the split's length. Every mutating helper returns a fresh tree and runs the
/// result through `normalized()` so ratios and arity invariants always hold.
indirect enum PaneNode: Codable, Equatable, Sendable {
    case leaf(UUID)
    case split(axis: Axis, children: [PaneNode], ratios: [CGFloat])

    /// Smallest width/height (points) a leaf is ever given by `frames(in:gap:)`.
    static let minLeafLength: CGFloat = 120

    // MARK: Queries

    /// Leaf session ids in visual order: left→right for horizontal splits, top→bottom for vertical.
    func leaves() -> [UUID] {
        switch self {
        case .leaf(let id):
            return [id]
        case .split(_, let children, _):
            return children.flatMap { $0.leaves() }
        }
    }

    func contains(_ id: UUID) -> Bool {
        switch self {
        case .leaf(let leafID):
            return leafID == id
        case .split(_, let children, _):
            return children.contains { $0.contains(id) }
        }
    }

    /// Number of splits between the root and the deepest leaf (`0` for a bare leaf).
    var depth: Int {
        switch self {
        case .leaf:
            return 0
        case .split(_, let children, _):
            return 1 + (children.map(\.depth).max() ?? 0)
        }
    }

    // MARK: Mutations (all return a normalized tree)

    /// Insert `newLeaf` next to the leaf `id`. If `id`'s parent split already runs along
    /// `axis`, the new leaf joins that split by halving `id`'s slot (siblings don't move).
    /// Otherwise `id` is replaced by a two-child split along `axis`. `after` puts the new
    /// leaf to the right/below the target; otherwise to the left/above.
    func insert(besideLeaf id: UUID, axis: Axis, newLeaf: UUID, after: Bool) -> PaneNode {
        guard contains(id), !contains(newLeaf) else { return self }
        return _insert(besideLeaf: id, axis: axis, newLeaf: newLeaf, after: after).normalized()
    }

    private func _insert(besideLeaf id: UUID, axis: Axis, newLeaf: UUID, after: Bool) -> PaneNode {
        switch self {
        case .leaf(let leafID):
            guard leafID == id else { return self }
            let pair: [PaneNode] = after ? [.leaf(id), .leaf(newLeaf)] : [.leaf(newLeaf), .leaf(id)]
            return .split(axis: axis, children: pair, ratios: [0.5, 0.5])

        case .split(let selfAxis, var children, var ratios):
            // Direct child that is the target leaf?
            if let idx = children.firstIndex(of: .leaf(id)), selfAxis == axis {
                let insertAt = after ? idx + 1 : idx
                let half = ratios[idx] / 2
                ratios[idx] = half
                ratios.insert(half, at: insertAt)
                children.insert(.leaf(newLeaf), at: insertAt)
                return .split(axis: selfAxis, children: children, ratios: ratios)
            }
            // Recurse into whichever branch owns the target.
            for i in children.indices where children[i].contains(id) {
                children[i] = children[i]._insert(besideLeaf: id, axis: axis, newLeaf: newLeaf, after: after)
                break
            }
            return .split(axis: selfAxis, children: children, ratios: ratios)
        }
    }

    /// Remove the leaf `id`. Splits left with a single child collapse into that child;
    /// an emptied tree yields `nil`. Returns `self` unchanged if `id` isn't present.
    func remove(leaf id: UUID) -> PaneNode? {
        guard contains(id) else { return self }
        return _remove(leaf: id)?.normalized()
    }

    private func _remove(leaf id: UUID) -> PaneNode? {
        switch self {
        case .leaf(let leafID):
            return leafID == id ? nil : self
        case .split(let axis, let children, let ratios):
            var newChildren: [PaneNode] = []
            var newRatios: [CGFloat] = []
            for (child, ratio) in zip(children, ratios) {
                if let kept = child._remove(leaf: id) {
                    newChildren.append(kept)
                    newRatios.append(ratio)
                }
            }
            switch newChildren.count {
            case 0: return nil
            case 1: return newChildren[0]
            default: return .split(axis: axis, children: newChildren, ratios: newRatios)
            }
        }
    }

    /// Exchange the positions of two existing leaves. No-op if either id is missing.
    func swap(_ a: UUID, _ b: UUID) -> PaneNode {
        guard a != b, contains(a), contains(b) else { return self }
        return _mapLeaves { $0 == a ? b : ($0 == b ? a : $0) }
    }

    private func _mapLeaves(_ transform: (UUID) -> UUID) -> PaneNode {
        switch self {
        case .leaf(let id):
            return .leaf(transform(id))
        case .split(let axis, let children, let ratios):
            return .split(axis: axis, children: children.map { $0._mapLeaves(transform) }, ratios: ratios)
        }
    }

    /// Set the ratio of the divider at `dividerIndex` inside the split that directly holds
    /// leaf `id`. `r` is the fraction of that divider's *pair* given to the earlier child;
    /// it is clamped to `0.05...0.95`. The pair's combined share is preserved, so other
    /// siblings and the rest of the tree don't move.
    func setRatio(atSplitContaining id: UUID, dividerIndex: Int, to r: CGFloat) -> PaneNode {
        _setRatio(atSplitContaining: id, dividerIndex: dividerIndex, to: r).normalized()
    }

    private func _setRatio(atSplitContaining id: UUID, dividerIndex: Int, to r: CGFloat) -> PaneNode {
        switch self {
        case .leaf:
            return self
        case .split(let axis, var children, var ratios):
            if children.contains(.leaf(id)),
               dividerIndex >= 0, dividerIndex + 1 < ratios.count {
                let i = dividerIndex
                let pairSum = ratios[i] + ratios[i + 1]
                let frac = min(max(r, 0.05), 0.95)
                ratios[i] = pairSum * frac
                ratios[i + 1] = pairSum - ratios[i]
                return .split(axis: axis, children: children, ratios: ratios)
            }
            for j in children.indices where children[j].contains(id) {
                children[j] = children[j]._setRatio(atSplitContaining: id, dividerIndex: dividerIndex, to: r)
                break
            }
            return .split(axis: axis, children: children, ratios: ratios)
        }
    }

    /// Even out every split so all children of each split share its length equally.
    func equalized() -> PaneNode {
        switch self {
        case .leaf:
            return self
        case .split(let axis, let children, _):
            let even = Array(repeating: 1 / CGFloat(children.count), count: children.count)
            return .split(axis: axis, children: children.map { $0.equalized() }, ratios: even)
        }
    }

    // MARK: Normalization

    /// Repair structural drift: collapse single-child splits, drop empty ones, and force
    /// every `ratios` array to match its `children` count and sum to 1 with positive entries.
    func normalized() -> PaneNode {
        switch self {
        case .leaf:
            return self
        case .split(let axis, let rawChildren, let rawRatios):
            let children = rawChildren.map { $0.normalized() }
            if children.count == 1 { return children[0] }
            if children.isEmpty { return .leaf(UUID()) } // unreachable via public API; keeps type total

            var ratios = rawRatios
            if ratios.count != children.count {
                ratios = Array(repeating: 1 / CGFloat(children.count), count: children.count)
            }
            ratios = ratios.map { $0.isFinite && $0 > 0 ? $0 : 0 }
            var total = ratios.reduce(0, +)
            if total <= 0 {
                ratios = Array(repeating: 1 / CGFloat(children.count), count: children.count)
                total = 1
            }
            ratios = ratios.map { $0 / total }
            return .split(axis: axis, children: children, ratios: ratios)
        }
    }

    // MARK: Geometry

    /// Lay the tree out inside `rect`, leaving `gap` points between adjacent children of a
    /// split. Every leaf is guaranteed at least `minLeafLength` on each axis (subject to the
    /// rect being large enough). Shared by the renderer and by `focusNeighbor`.
    func frames(in rect: CGRect, gap: CGFloat = 0) -> [UUID: CGRect] {
        switch self {
        case .leaf(let id):
            return [id: rect]
        case .split(let axis, let children, let ratios):
            let horizontal = axis == .horizontal
            let total = horizontal ? rect.width : rect.height
            let n = children.count
            let available = max(0, total - gap * CGFloat(n - 1))
            let lengths = PaneNode.partition(available, ratios: ratios)

            var result: [UUID: CGRect] = [:]
            var offset = horizontal ? rect.minX : rect.minY
            for (child, length) in zip(children, lengths) {
                let childRect = horizontal
                    ? CGRect(x: offset, y: rect.minY, width: length, height: rect.height)
                    : CGRect(x: rect.minX, y: offset, width: rect.width, height: length)
                result.merge(child.frames(in: childRect, gap: gap)) { _, new in new }
                offset += length + gap
            }
            return result
        }
    }

    /// Split `available` into `ratios.count` slices, honouring the ratios but floored at
    /// `minLeafLength` (or an equal share when even that doesn't fit).
    private static func partition(_ available: CGFloat, ratios: [CGFloat]) -> [CGFloat] {
        let n = ratios.count
        guard n > 0 else { return [] }
        let equalShare = available / CGFloat(n)
        let floorLen = min(minLeafLength, equalShare)

        var lengths = ratios.map { max(available * $0, floorLen) }
        let overflow = lengths.reduce(0, +) - available
        if overflow > 0 {
            // Shave the excess off slices that still have slack above the floor.
            let slack = lengths.map { max(0, $0 - floorLen) }
            let slackTotal = slack.reduce(0, +)
            if slackTotal > 0 {
                for i in lengths.indices {
                    lengths[i] -= overflow * (slack[i] / slackTotal)
                }
            }
        }
        return lengths
    }

    // MARK: Dividers (renderer drag handles)

    /// One draggable split boundary: the `path` of child indices from the root to the split
    /// that owns it, the `index` of the child immediately before the boundary, the split's
    /// `axis`, the handle's hit `rect`, and `pairRect` — the combined span of the two panes
    /// the handle resizes. All rects share the coordinate space of `frames(in:gap:)`.
    struct DividerSpec: Equatable {
        let path: [Int]
        let index: Int
        let axis: Axis
        let rect: CGRect
        let pairRect: CGRect
        /// Stable identity for `ForEach` — a split's position plus which boundary it is.
        var id: String { path.map(String.init).joined(separator: ".") + "#\(index)" }
    }

    func dividers(in rect: CGRect, gap: CGFloat = 0, thickness: CGFloat = 10) -> [DividerSpec] {
        _dividers(in: rect, gap: gap, thickness: thickness, path: [])
    }

    private func _dividers(in rect: CGRect, gap: CGFloat, thickness: CGFloat, path: [Int]) -> [DividerSpec] {
        guard case .split(let axis, let children, let ratios) = self else { return [] }
        let horizontal = axis == .horizontal
        let available = max(0, (horizontal ? rect.width : rect.height) - gap * CGFloat(children.count - 1))
        let lengths = PaneNode.partition(available, ratios: ratios)

        var childRects: [CGRect] = []
        var offset = horizontal ? rect.minX : rect.minY
        for length in lengths {
            childRects.append(horizontal
                ? CGRect(x: offset, y: rect.minY, width: length, height: rect.height)
                : CGRect(x: rect.minX, y: offset, width: rect.width, height: length))
            offset += length + gap
        }

        var specs: [DividerSpec] = []
        for i in children.indices {
            specs += children[i]._dividers(in: childRects[i], gap: gap, thickness: thickness, path: path + [i])
            guard i < children.count - 1 else { continue }
            let a = childRects[i], b = childRects[i + 1]
            let center = horizontal ? (a.maxX + b.minX) / 2 : (a.maxY + b.minY) / 2
            let handle = horizontal
                ? CGRect(x: center - thickness / 2, y: rect.minY, width: thickness, height: rect.height)
                : CGRect(x: rect.minX, y: center - thickness / 2, width: rect.width, height: thickness)
            specs.append(DividerSpec(path: path, index: i, axis: axis, rect: handle, pairRect: a.union(b)))
        }
        return specs
    }

    /// Set the ratio of the divider `dividerIndex` inside the split reached by following
    /// `path` (child indices) from the root. `r` is the earlier pane's fraction of that
    /// divider's pair, clamped to `0.05...0.95`; the pair's combined share is preserved.
    func settingRatio(at path: [Int], dividerIndex: Int, to r: CGFloat) -> PaneNode {
        _settingRatio(at: path[...], dividerIndex: dividerIndex, to: r).normalized()
    }

    private func _settingRatio(at path: ArraySlice<Int>, dividerIndex: Int, to r: CGFloat) -> PaneNode {
        guard case .split(let axis, var children, var ratios) = self else { return self }
        if let head = path.first {
            guard children.indices.contains(head) else { return self }
            children[head] = children[head]._settingRatio(at: path.dropFirst(), dividerIndex: dividerIndex, to: r)
            return .split(axis: axis, children: children, ratios: ratios)
        }
        guard dividerIndex >= 0, dividerIndex + 1 < ratios.count else { return self }
        let pairSum = ratios[dividerIndex] + ratios[dividerIndex + 1]
        let frac = min(max(r, 0.05), 0.95)
        ratios[dividerIndex] = pairSum * frac
        ratios[dividerIndex + 1] = pairSum - ratios[dividerIndex]
        return .split(axis: axis, children: children, ratios: ratios)
    }

    /// The leaf a directional focus move from `id` should land on, decided purely by the
    /// laid-out rectangles. Considers only candidates on the requested side that overlap
    /// `id` along the perpendicular axis, then picks the nearest one, breaking ties by the
    /// greater overlap. Origin is top-left, so `.up` means smaller `y`.
    func focusNeighbor(of id: UUID,
                       direction: Direction,
                       in rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                       gap: CGFloat = 0) -> UUID? {
        let boxes = frames(in: rect, gap: gap)
        guard let origin = boxes[id] else { return nil }
        let slack: CGFloat = 0.5

        var best: UUID?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestOverlap: CGFloat = -1

        for (candidate, box) in boxes where candidate != id {
            let onSide: Bool
            let distance: CGFloat
            let overlap: CGFloat
            switch direction {
            case .left:
                onSide = box.midX < origin.midX && box.maxX <= origin.minX + slack
                distance = origin.minX - box.maxX
                overlap = overlapLength(origin.minY, origin.maxY, box.minY, box.maxY)
            case .right:
                onSide = box.midX > origin.midX && box.minX >= origin.maxX - slack
                distance = box.minX - origin.maxX
                overlap = overlapLength(origin.minY, origin.maxY, box.minY, box.maxY)
            case .up:
                onSide = box.midY < origin.midY && box.maxY <= origin.minY + slack
                distance = origin.minY - box.maxY
                overlap = overlapLength(origin.minX, origin.maxX, box.minX, box.maxX)
            case .down:
                onSide = box.midY > origin.midY && box.minY >= origin.maxY - slack
                distance = box.minY - origin.maxY
                overlap = overlapLength(origin.minX, origin.maxX, box.minX, box.maxX)
            }
            guard onSide, overlap > 0 else { continue }
            let closer = distance < bestDistance - 0.001
            let tied = abs(distance - bestDistance) <= 0.001
            if closer || (tied && overlap > bestOverlap) {
                best = candidate
                bestDistance = distance
                bestOverlap = overlap
            }
        }
        return best
    }

    private func overlapLength(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> CGFloat {
        max(0, min(a1, b1) - max(a0, b0))
    }

    // MARK: Codable — discriminated, and forgiving about drifted ratios

    private enum CodingKeys: String, CodingKey {
        case type, id, axis, children, ratios
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "leaf":
            self = .leaf(try c.decode(UUID.self, forKey: .id))
        case "split":
            let axis = try c.decodeIfPresent(Axis.self, forKey: .axis) ?? .horizontal
            let children = try c.decode([PaneNode].self, forKey: .children)
            guard !children.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .children, in: c,
                    debugDescription: "split with no children")
            }
            let ratios = try c.decodeIfPresent([CGFloat].self, forKey: .ratios) ?? []
            self = PaneNode.split(axis: axis, children: children, ratios: ratios).normalized()
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "unknown PaneNode type \"\(other)\"")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .leaf(let id):
            try c.encode("leaf", forKey: .type)
            try c.encode(id, forKey: .id)
        case .split(let axis, let children, let ratios):
            try c.encode("split", forKey: .type)
            try c.encode(axis, forKey: .axis)
            try c.encode(children, forKey: .children)
            try c.encode(ratios, forKey: .ratios)
        }
    }
}
