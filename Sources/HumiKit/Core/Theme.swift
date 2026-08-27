import AppKit
import SwiftUI
import SwiftTerm

/// An sRGB colour stored as `0xRRGGBB`, Codable as that integer.
struct HexColor: Codable, Equatable, Hashable, Sendable {
    var value: UInt32

    init(_ value: UInt32) { self.value = value & 0xFFFFFF }
    init(r: UInt8, g: UInt8, b: UInt8) { value = (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b) }

    init(from decoder: Decoder) throws { value = (try decoder.singleValueContainer().decode(UInt32.self)) & 0xFFFFFF }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }

    var r: UInt8 { UInt8((value >> 16) & 0xFF) }
    var g: UInt8 { UInt8((value >> 8) & 0xFF) }
    var b: UInt8 { UInt8(value & 0xFF) }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
    var swiftUI: SwiftUI.Color { SwiftUI.Color(nsColor) }
    var swiftTerm: SwiftTerm.Color { SwiftTerm.Color(red: scale(r), green: scale(g), blue: scale(b)) }
    private func scale(_ c: UInt8) -> UInt16 { UInt16(c) << 8 | UInt16(c) }

    init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? ns
        self.init(r: UInt8((c.redComponent * 255).rounded()),
                  g: UInt8((c.greenComponent * 255).rounded()),
                  b: UInt8((c.blueComponent * 255).rounded()))
    }

    /// `"#rrggbb"` — used by `.humitheme` files and hex text fields.
    var hexString: String { String(format: "#%06x", value) }
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        self.init(n)
    }
}

/// Cursor appearance — a shape plus whether it blinks. Maps onto SwiftTerm's 6 cases.
struct CursorSpec: Codable, Equatable, Sendable {
    enum Shape: String, Codable, CaseIterable, Identifiable, Sendable {
        case block, underline, bar
        var id: String { rawValue }
    }
    var shape: Shape = .block
    var blink: Bool = true

    var swiftTerm: CursorStyle {
        switch (shape, blink) {
        case (.block, true):     return .blinkBlock
        case (.block, false):    return .steadyBlock
        case (.underline, true): return .blinkUnderline
        case (.underline, false):return .steadyUnderline
        case (.bar, true):       return .blinkBar
        case (.bar, false):      return .steadyBar
        }
    }
}

enum AppAppearance: String, Codable, Sendable { case light, dark }

/// A complete terminal + chrome colour/font theme.
struct Theme: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool

    var background: HexColor
    var foreground: HexColor
    var cursor: HexColor
    var cursorText: HexColor?
    var selectionBackground: HexColor
    var selectionForeground: HexColor?
    /// 16 ANSI colours: 0–7 normal, 8–15 bright.
    var ansi: [HexColor]

    var fontFamily: String            // "" == system monospaced
    var fontSize: Double
    var boldFontFamily: String?
    var italicFontFamily: String?
    var cjkFontFamily: String?        // appended to the cascade list for CJK coverage
    var useBrightBold: Bool
    var cursorSpec: CursorSpec

    /// Which app-chrome palette this theme pairs with, and the light/dark sibling to
    /// switch to under "System" mode.
    var appAppearance: AppAppearance
    var pairedThemeName: String?

    static func decodeIfPresent(_ data: Data) -> Theme? {
        try? JSONDecoder().decode(Theme.self, from: data)
    }

    // Custom decode so older/partial `.humitheme` files still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Imported"
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        background = try c.decode(HexColor.self, forKey: .background)
        foreground = try c.decode(HexColor.self, forKey: .foreground)
        cursor = try c.decodeIfPresent(HexColor.self, forKey: .cursor) ?? foreground
        cursorText = try c.decodeIfPresent(HexColor.self, forKey: .cursorText)
        selectionBackground = try c.decodeIfPresent(HexColor.self, forKey: .selectionBackground) ?? HexColor(0x4FB7E8)
        selectionForeground = try c.decodeIfPresent(HexColor.self, forKey: .selectionForeground)
        let a = try c.decodeIfPresent([HexColor].self, forKey: .ansi) ?? []
        ansi = a.count == 16 ? a : Theme.defaultAnsi
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? ""
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 13
        boldFontFamily = try c.decodeIfPresent(String.self, forKey: .boldFontFamily)
        italicFontFamily = try c.decodeIfPresent(String.self, forKey: .italicFontFamily)
        cjkFontFamily = try c.decodeIfPresent(String.self, forKey: .cjkFontFamily)
        useBrightBold = try c.decodeIfPresent(Bool.self, forKey: .useBrightBold) ?? true
        cursorSpec = try c.decodeIfPresent(CursorSpec.self, forKey: .cursorSpec) ?? CursorSpec()
        appAppearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appAppearance) ?? .light
        pairedThemeName = try c.decodeIfPresent(String.self, forKey: .pairedThemeName)
    }

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool,
         background: UInt32, foreground: UInt32, cursor: UInt32,
         cursorText: UInt32? = nil, selectionBackground: UInt32, selectionForeground: UInt32? = nil,
         ansi: [UInt32], fontSize: Double = 13, fontFamily: String = "",
         useBrightBold: Bool = true, cursorSpec: CursorSpec = CursorSpec(),
         appAppearance: AppAppearance = .light, pairedThemeName: String? = nil) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.background = HexColor(background)
        self.foreground = HexColor(foreground)
        self.cursor = HexColor(cursor)
        self.cursorText = cursorText.map(HexColor.init)
        self.selectionBackground = HexColor(selectionBackground)
        self.selectionForeground = selectionForeground.map(HexColor.init)
        self.ansi = ansi.map(HexColor.init)
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.boldFontFamily = nil
        self.italicFontFamily = nil
        self.cjkFontFamily = nil
        self.useBrightBold = useBrightBold
        self.cursorSpec = cursorSpec
        self.appAppearance = appAppearance
        self.pairedThemeName = pairedThemeName
    }

    static let defaultAnsi: [HexColor] = [
        0x1B1D22, 0xCE4E30, 0x3FA875, 0xCBAE2E, 0x2E93C6, 0x8B6FC9, 0x2E93C6, 0x5B5E66,
        0x808790, 0xF2704F, 0x6FD09B, 0xF1D64A, 0x4FB7E8, 0xB79BE8, 0x7FD4E8, 0x1B1D22,
    ].map(HexColor.init)
}

// MARK: - Built-in presets

extension Theme {
    static let humLight = Theme(
        name: "Hum Light", isBuiltIn: true,
        background: 0xF7F4EC, foreground: 0x1B1D22, cursor: 0xCBAE2E,
        selectionBackground: 0x4FB7E8,
        ansi: [0x1B1D22,0xCE4E30,0x3FA875,0xCBAE2E,0x2E93C6,0x8B6FC9,0x2E93C6,0x5B5E66,
               0x808790,0xF2704F,0x6FD09B,0xF1D64A,0x4FB7E8,0xB79BE8,0x7FD4E8,0x1B1D22],
        appAppearance: .light, pairedThemeName: "Hum Dark")

    static let humDark = Theme(
        name: "Hum Dark", isBuiltIn: true,
        background: 0x191B20, foreground: 0xE9E6DC, cursor: 0xF1D64A,
        selectionBackground: 0x2E93C6,
        ansi: [0x3A3D45,0xF2704F,0x6FD09B,0xF1D64A,0x4FB7E8,0xB79BE8,0x7FD4E8,0xC9C6BC,
               0x5B5E66,0xF7906F,0x8FE0B4,0xF6E27A,0x74C8ED,0xC9B4F0,0xA9E4F2,0xF3F1E9],
        appAppearance: .dark, pairedThemeName: "Hum Light")

    static let solarizedLight = Theme(
        name: "Solarized Light", isBuiltIn: true,
        background: 0xFDF6E3, foreground: 0x657B83, cursor: 0x586E75,
        selectionBackground: 0xEEE8D5,
        ansi: [0x073642,0xDC322F,0x859900,0xB58900,0x268BD2,0xD33682,0x2AA198,0xEEE8D5,
               0x002B36,0xCB4B16,0x586E75,0x657B83,0x839496,0x6C71C4,0x93A1A1,0xFDF6E3],
        appAppearance: .light, pairedThemeName: "Solarized Dark")

    static let solarizedDark = Theme(
        name: "Solarized Dark", isBuiltIn: true,
        background: 0x002B36, foreground: 0x839496, cursor: 0x93A1A1,
        selectionBackground: 0x073642,
        ansi: [0x073642,0xDC322F,0x859900,0xB58900,0x268BD2,0xD33682,0x2AA198,0xEEE8D5,
               0x002B36,0xCB4B16,0x586E75,0x657B83,0x839496,0x6C71C4,0x93A1A1,0xFDF6E3],
        appAppearance: .dark, pairedThemeName: "Solarized Light")

    static let nord = Theme(
        name: "Nord", isBuiltIn: true,
        background: 0x2E3440, foreground: 0xD8DEE9, cursor: 0xD8DEE9,
        selectionBackground: 0x434C5E,
        ansi: [0x3B4252,0xBF616A,0xA3BE8C,0xEBCB8B,0x81A1C1,0xB48EAD,0x88C0D0,0xE5E9F0,
               0x4C566A,0xBF616A,0xA3BE8C,0xEBCB8B,0x81A1C1,0xB48EAD,0x8FBCBB,0xECEFF4],
        appAppearance: .dark, pairedThemeName: "Hum Light")

    static let terminalBasic = Theme(
        name: "Terminal Basic", isBuiltIn: true,
        background: 0xFFFFFF, foreground: 0x000000, cursor: 0x000000,
        selectionBackground: 0xB4D5FE,
        ansi: [0x000000,0x990000,0x00A600,0x999900,0x0000B2,0xB200B2,0x00A6B2,0xBFBFBF,
               0x666666,0xE50000,0x00D900,0xE5E500,0x0000FF,0xE500E5,0x00E5E5,0xE5E5E5],
        appAppearance: .light, pairedThemeName: "Terminal Basic")

    static let builtIns: [Theme] = [humLight, humDark, solarizedLight, solarizedDark, nord, terminalBasic]
}
