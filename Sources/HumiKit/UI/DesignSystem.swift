import SwiftUI
import AppKit

/// Hum theme, translated to native macOS.
/// Cream paper, multi-accent (pear / cyan / coral / mint / lavender), rounded surfaces,
/// "push" buttons whose press is the feedback. No serif anywhere, never pure white / pure black.
public enum Hum {

    // MARK: Palette (oklch values from hallmark, converted to sRGB)

    static let paper       = Color(hex: 0xF7F4EC)   // oklch(97% .012 95) — cream, slight pear pull
    static let paper2      = Color(hex: 0xEFEBDC)   // tinted band
    static let paper3      = Color(hex: 0xE6E0CC)   // deeper hover
    static let ink         = Color(hex: 0x1B1D22)   // oklch(20% .012 250) — never pure black
    static let ink2        = Color(hex: 0x5B5E66)   // secondary ink
    static let hairline    = Color(hex: 0x1B1D22).opacity(0.10)

    static let pear        = Color(hex: 0xF1D64A)   // primary — CTA, character mark
    static let pearDeep    = Color(hex: 0xCBAE2E)   // button edge / pressed line
    static let cyan        = Color(hex: 0x4FB7E8)   // links, hover tints
    static let cyanDeep    = Color(hex: 0x2E93C6)
    static let coral       = Color(hex: 0xF2704F)   // single high-energy moment
    static let coralDeep   = Color(hex: 0xCE4E30)
    static let mint        = Color(hex: 0x6FD09B)   // success, sparse
    static let lavender    = Color(hex: 0xB79BE8)   // decorative, sparse
    static let focusRing   = Color(hex: 0x2E93C6)

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
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
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

// MARK: - The push button. The press is the feedback: lift on hover, sink on press.
// No scale(), no spring overshoot on the press itself.

struct HumButtonStyle: ButtonStyle {
    enum Kind { case push, soft, outline }
    var kind: Kind = .push
    var accent: Hum.Accent = Hum.accent(0)
    var size: CGFloat = 15

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(Hum.Font.display(size, weight: .semibold))
            .foregroundStyle(kind == .push ? Hum.ink : Hum.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(background(pressed: pressed))
            .offset(y: offsetY(pressed: pressed))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: pressed ? 0.07 : 0.14), value: pressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Hum.Radius.pill, style: .continuous)
        switch kind {
        case .push:
            shape.fill(accent.tint)
                .background(
                    shape.fill(accent.edge)
                        .offset(y: pressed ? 1 : (edgeThickness))
                )
                .shadow(color: accent.tint.opacity(0.45),
                        radius: pressed ? 3 : 10, x: 0, y: pressed ? 2 : 8)
        case .soft:
            shape.fill(Hum.paper)
                .shadow(color: Hum.ink.opacity(0.12), radius: pressed ? 4 : 12, x: 0, y: pressed ? 2 : 6)
        case .outline:
            shape.strokeBorder(Hum.ink.opacity(0.35), lineWidth: 1.5)
                .background(shape.fill(pressed ? accent.tint.opacity(0.18) : .clear))
        }
    }

    private var edgeThickness: CGFloat { 4 }
    private func offsetY(pressed: Bool) -> CGFloat {
        guard kind == .push else { return pressed ? 1 : 0 }
        return pressed ? 3 : 0
    }
}

extension ButtonStyle where Self == HumButtonStyle {
    static func hum(_ kind: HumButtonStyle.Kind = .push, accent: Hum.Accent = Hum.accent(0), size: CGFloat = 15) -> HumButtonStyle {
        HumButtonStyle(kind: kind, accent: accent, size: size)
    }
}
