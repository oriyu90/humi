import Foundation

/// Pure helpers for the session grid, kept out of the View so they're unit-testable.
enum GridLayout {
    /// Number of columns that fit `width`, given a minimum tile width and gutter.
    static func columnCount(width: CGFloat, minTileWidth: CGFloat, spacing: CGFloat) -> Int {
        guard width > 0, minTileWidth > 0 else { return 1 }
        return max(1, Int((width - spacing) / (minTileWidth + spacing)))
    }

    /// Split `items` into rows of at most `size`.
    static func chunk<T>(_ items: [T], into size: Int) -> [[T]] {
        guard size > 0 else { return items.isEmpty ? [] : [items] }
        return stride(from: 0, to: items.count, by: size).map {
            Array(items[$0 ..< min($0 + size, items.count)])
        }
    }
}
