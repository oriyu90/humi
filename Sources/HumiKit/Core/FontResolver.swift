import AppKit

/// Builds the terminal `NSFont` for a theme: the chosen monospaced family at a size,
/// with an optional CJK face appended as a fallback so Japanese/Chinese glyphs render
/// even when the primary face has no CJK coverage.
enum FontResolver {

    /// Bundled default, matching the historical `TerminalController.monoFont`.
    static func fallbackMono(_ size: CGFloat) -> NSFont {
        NSFont(name: "JetBrains Mono", size: size)
            ?? NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func terminalFont(family: String, size: CGFloat, cjkFamily: String?) -> NSFont {
        let base: NSFont
        if family.isEmpty {
            base = fallbackMono(size)
        } else if let f = NSFont(name: family, size: size) {
            base = f
        } else {
            // A family name (not a PostScript name) — resolve via a descriptor.
            let desc = NSFontDescriptor(fontAttributes: [.family: family, .size: size])
            base = NSFont(descriptor: desc, size: size) ?? fallbackMono(size)
        }
        guard let cjk = cjkFamily, !cjk.isEmpty else { return base }

        let cascade = NSFontDescriptor(fontAttributes: [.family: cjk])
        let merged = base.fontDescriptor.addingAttributes([.cascadeList: [cascade]])
        return NSFont(descriptor: merged, size: size) ?? base
    }

    /// Monospaced family names for the picker, plus a leading "" entry meaning
    /// "system monospaced".
    static func monospacedFamilies() -> [String] {
        let mgr = NSFontManager.shared
        let fixedPitch: UInt = 1 << 10   // NSFontTraitMask.fixedPitchFontMask
        let names = mgr.availableFontFamilies.filter { fam in
            guard let members = mgr.availableMembers(ofFontFamily: fam) else { return false }
            return members.contains { member in
                guard member.count >= 4, let traits = member[3] as? Int else { return false }
                return UInt(traits) & fixedPitch != 0
            }
        }
        return [""] + names.sorted()
    }
}
