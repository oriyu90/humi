import SwiftUI
import AppKit

/// Hum theme, translated to native macOS.
/// Cream paper, multi-accent (pear / cyan / coral / mint / lavender), rounded surfaces,
/// "push" buttons whose press is the feedback. No serif anywhere, never pure white / pure black.
public enum Hum {

    // MARK: Palette (oklch values from hallmark, converted to sRGB)
    //
    // Chrome tokens are dynamic `NSColor`s: they resolve light/dark against the
    // hosting view's appearance, which the windows set from
    // `ThemeStore.resolvedTheme.appAppearance`. No `@MainActor` needed on the tokens.

    /// A colour that resolves to `light` in aqua and `dark` in dark-aqua.
    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    /// Raw hex values behind the dynamic chrome tokens. Named so the contrast self-test
    /// can check the light/dark pairs without re-deriving them.
    public enum RGB {
        public static let paperL: UInt32 = 0xF7F4EC, paperD: UInt32 = 0x191B20
        public static let paper2L: UInt32 = 0xEFEBDC, paper2D: UInt32 = 0x212329
        public static let paper3L: UInt32 = 0xE6E0CC, paper3D: UInt32 = 0x2C2F37
        public static let inkL: UInt32 = 0x1B1D22, inkD: UInt32 = 0xE9E6DC
        public static let ink2L: UInt32 = 0x5B5E66, ink2D: UInt32 = 0x9A9C9F
        public static let focusRingL: UInt32 = 0x1668A0, focusRingD: UInt32 = 0x4FB7E8
        public static let pearDeep: UInt32 = 0xCBAE2E
    }

    static let paper       = dyn(light: RGB.paperL, dark: RGB.paperD)   // cream / near-black
    static let paper2      = dyn(light: RGB.paper2L, dark: RGB.paper2D)  // tinted band
    static let paper3      = dyn(light: RGB.paper3L, dark: RGB.paper3D)  // deeper hover
    static let ink         = dyn(light: RGB.inkL, dark: RGB.inkD)        // never pure black / white
    static let ink2        = dyn(light: RGB.ink2L, dark: RGB.ink2D)      // secondary ink
    static let hairline    = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let boost = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return NSColor(hex: isDark ? 0xFFFFFF : 0x1B1D22)
            .withAlphaComponent(boost ? (isDark ? 0.28 : 0.24) : (isDark ? 0.12 : 0.10))
    })

    /// Whether the OS "Increase contrast" setting is on. Read at call time.
    static var increaseContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    /// Accent wash opacity for a tile surface — firmer under "Increase contrast".
    static func tileTintOpacity(hovering: Bool) -> Double {
        increaseContrast ? (hovering ? 0.20 : 0.12) : (hovering ? 0.12 : 0.06)
    }

    // MARK: WCAG contrast (used by the Contrast self-test and by contrast-aware UI)

    /// sRGB relative luminance (WCAG 2.1).
    public static func luminance(_ hex: UInt32) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = lin(Double((hex >> 16) & 0xFF) / 255)
        let g = lin(Double((hex >> 8) & 0xFF) / 255)
        let b = lin(Double(hex & 0xFF) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// WCAG contrast ratio between two opaque sRGB colours (1…21).
    public static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static let pear        = Color(hex: 0xF1D64A)   // primary — CTA, character mark
    static let pearDeep    = Color(hex: 0xCBAE2E)   // button edge / pressed line
    static let cyan        = Color(hex: 0x4FB7E8)   // links, hover tints
    static let cyanDeep    = Color(hex: 0x2E93C6)
    static let coral       = Color(hex: 0xF2704F)   // single high-energy moment
    static let coralDeep   = Color(hex: 0xCE4E30)
    static let mint        = Color(hex: 0x6FD09B)   // success, sparse
    static let lavender    = Color(hex: 0xB79BE8)   // decorative, sparse
    static let focusRing   = dyn(light: RGB.focusRingL, dark: RGB.focusRingD)

    /// The per-tile accent rotation. Each surface owns one accent; they never blend.
    static let accents: [Accent] = [
        Accent(tint: pear,     edge: pearDeep),
        Accent(tint: cyan,     edge: cyanDeep),
        Accent(tint: coral,    edge: coralDeep),
        Accent(tint: mint,     edge: Color(hex: 0x3FA875)),
        Accent(tint: lavender, edge: Color(hex: 0x8B6FC9)),
    ]

    struct Accent {
        let tint: Color
        let edge: Color
    }

    static func accent(_ index: Int) -> Accent {
        accents[((index % accents.count) + accents.count) % accents.count]
    }

    static let accentNames = ["Pear", "Cyan", "Coral", "Mint", "Lavender"]
    static func accentName(_ index: Int) -> String {
        accentNames[((index % accentNames.count) + accentNames.count) % accentNames.count]
    }

    // MARK: Radii — angular corners are forbidden in Hum
    enum Radius {
        static let card: CGFloat  = 20
        static let tile: CGFloat  = 16
        static let input: CGFloat = 12
        static let pill: CGFloat  = 999
    }

    // MARK: Spacing — 4pt scale
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
    }

    // MARK: Type
    enum Font {
        static let displayName = "Plus Jakarta Sans"
        static let monoName    = "JetBrains Mono"

        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            custom(displayName, size: size, weight: weight, fallback: .system(size: size, weight: weight, design: .rounded))
        }
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            custom(displayName, size: size, weight: weight, fallback: .system(size: size, weight: weight, design: .rounded))
        }
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            custom(monoName, size: size, weight: weight, fallback: .system(size: size, weight: weight, design: .monospaced))
        }

        private static func custom(_ name: String, size: CGFloat, weight: SwiftUI.Font.Weight, fallback: SwiftUI.Font) -> SwiftUI.Font {
            if NSFont(name: name, size: size) != nil {
                return .custom(name, size: size).weight(weight)
            }
            return fallback
        }
    }

    // MARK: Motion
    enum Motion {
        static let spring = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.62)
        static let snap   = SwiftUI.Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)

        static var reduceMotion: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
        /// Spatial animation that collapses to a short crossfade under Reduce Motion.
        static func considerate(_ base: SwiftUI.Animation) -> SwiftUI.Animation {
            reduceMotion ? .easeOut(duration: 0.12) : base
        }
    }

    // MARK: Fonts — register the bundled faces once at launch
    public static func registerFonts() {
        let names = [
            "PlusJakartaSans-Regular", "PlusJakartaSans-Medium",
            "PlusJakartaSans-SemiBold", "PlusJakartaSans-Bold",
            "JetBrainsMono-Regular", "JetBrainsMono-Medium",
        ]
        for name in names {
            guard let url = Bundle.humiResources.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Focus ring (Hallmark: 3pt+ high-contrast, always identifiable)

extension View {
    /// A high-contrast keyboard-focus ring hugging `shape`. 3pt normally, 4pt under
    /// "Increase contrast". Pass `show` from a `@FocusState` / `isFocused`.
    func humFocusRing(_ show: Bool, cornerRadius: CGFloat = Hum.Radius.pill) -> some View {
        overlay {
            if show {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Hum.focusRing, lineWidth: Hum.increaseContrast ? 4 : 3)
                    .padding(-2)
            }
        }
    }
}

// MARK: - The push button. Every Hallmark state: default / hover / focus / pressed /
// disabled / loading / success / error. The press is the feedback; no scale().

enum HumStatus: Equatable { case idle, loading, success, error }

struct HumButtonStyle: ButtonStyle {
    enum Kind { case push, soft, outline }
    var kind: Kind = .push
    var accent: Hum.Accent = Hum.accent(0)
    var size: CGFloat = 15
    var status: HumStatus = .idle

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, kind: kind, accent: accent, size: size, status: status)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let kind: Kind
        let accent: Hum.Accent
        let size: CGFloat
        let status: HumStatus

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        private var edgeColor: Color {
            switch status {
            case .success: return Hum.mint
            case .error:   return Hum.coral
            default:       return accent.edge
            }
        }

        var body: some View {
            let pressed = configuration.isPressed || status == .loading
            HStack(spacing: 8) {
                switch status {
                case .loading: ProgressView().controlSize(.small)
                case .success: Image(systemName: "checkmark")
                case .error:   Image(systemName: "exclamationmark.triangle.fill")
                case .idle:    EmptyView()
                }
                configuration.label
            }
            .font(Hum.Font.display(size, weight: .semibold))
            .foregroundStyle(Hum.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(background(pressed: pressed))
            .offset(y: offsetY(pressed: pressed))
            .opacity(isEnabled && status != .loading ? 1 : 0.5)
            .brightness(hovering && isEnabled && status == .idle ? 0.04 : 0)
            .contentShape(Rectangle())
            .humFocusRing(isFocused && isEnabled)
            .onHover { hovering = $0 }
            .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: pressed ? 0.07 : 0.14), value: pressed)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }

        @ViewBuilder
        private func background(pressed: Bool) -> some View {
            let shape = RoundedRectangle(cornerRadius: Hum.Radius.pill, style: .continuous)
            switch kind {
            case .push:
                shape.fill(status == .idle ? accent.tint : edgeColor.opacity(0.9))
                    .background(shape.fill(edgeColor).offset(y: pressed ? 1 : 4))
                    .shadow(color: (status == .idle ? accent.tint : edgeColor).opacity(0.45),
                            radius: pressed ? 3 : (hovering ? 13 : 10), x: 0, y: pressed ? 2 : (hovering ? 9 : 8))
            case .soft:
                shape.fill(hovering ? Hum.paper3 : Hum.paper)
                    .shadow(color: Hum.ink.opacity(0.12), radius: pressed ? 4 : 12, x: 0, y: pressed ? 2 : 6)
            case .outline:
                shape.strokeBorder(Hum.ink.opacity(hovering ? 0.5 : 0.35), lineWidth: 1.5)
                    .background(shape.fill(pressed ? accent.tint.opacity(0.18)
                                          : (hovering ? accent.tint.opacity(0.08) : .clear)))
            }
        }

        private func offsetY(pressed: Bool) -> CGFloat {
            guard kind == .push else { return pressed ? 1 : 0 }
            return pressed ? 3 : (hovering && isEnabled ? -1 : 0)
        }
    }
}

extension ButtonStyle where Self == HumButtonStyle {
    static func hum(_ kind: HumButtonStyle.Kind = .push,
                    accent: Hum.Accent = Hum.accent(0),
                    size: CGFloat = 15,
                    status: HumStatus = .idle) -> HumButtonStyle {
        HumButtonStyle(kind: kind, accent: accent, size: size, status: status)
    }
}
