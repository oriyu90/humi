import AppKit
import Carbon.HIToolbox

/// A single process-wide global hotkey via Carbon's `RegisterEventHotKey`. Carbon is used
/// instead of an `NSEvent` global monitor because it needs no Accessibility permission and
/// reliably fires while another app is frontmost. Only one chord is registered at a time.
@MainActor
public final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onFire: (() -> Void)?
    private let signature: OSType = 0x484D4B31   // 'HMK1'

    private init() {}

    /// Whether a chord is currently registered with the system.
    var isRegistered: Bool { hotKeyRef != nil }

    // MARK: bootstrap (called once from the app)

    /// Wire the global hotkey to `AppSettings` and keep it in sync. Call once at launch.
    public static func bootstrap() {
        AppSettings.shared.onGlobalHotkeyChange = { apply() }
        apply()
    }

    static func apply() {
        let s = AppSettings.shared
        guard s.globalHotkeyEnabled else { shared.unregister(); return }
        _ = shared.register(s.globalHotkeyChord) { toggleMainWindow() }
    }

    /// Hotkey action: hide Humi if it's frontmost and showing, otherwise bring it up.
    static func toggleMainWindow() {
        guard let app = NSApp else { return }
        let window = app.keyWindow ?? app.windows.first { $0.canBecomeKey }
        if app.isActive, let window, window.isVisible, !window.isMiniaturized {
            app.hide(nil)
        } else {
            app.activate(ignoringOtherApps: true)
            window?.deminiaturize(nil)
            window?.makeKeyAndOrderFront(nil)
        }
    }

    /// Register `chord` globally. Returns `false` if the key is unmappable, the chord has
    /// no modifier, or the combo is already claimed by another app. Clears any prior
    /// registration first.
    @discardableResult
    func register(_ chord: KeyChord, onFire: @escaping () -> Void) -> Bool {
        unregister()
        guard let keyCode = Self.carbonKeyCode(for: chord.key) else { return false }
        let mods = Self.carbonModifiers(chord.eventModifiers)
        guard mods != 0 else { return false }

        self.onFire = onFire
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(UInt32(keyCode), mods, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { hotKeyRef = nil }
        return status == noErr && hotKeyRef != nil
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        onFire = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.onFire?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    // MARK: chord → Carbon

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    /// Map a `KeyChord.key` token to a Carbon virtual key code. Covers letters, digits,
    /// arrows, and a handful of punctuation — enough for a user-chosen toggle hotkey.
    static func carbonKeyCode(for key: String) -> Int? {
        switch key {
        case "a": return kVK_ANSI_A; case "b": return kVK_ANSI_B; case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D; case "e": return kVK_ANSI_E; case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G; case "h": return kVK_ANSI_H; case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J; case "k": return kVK_ANSI_K; case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M; case "n": return kVK_ANSI_N; case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P; case "q": return kVK_ANSI_Q; case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S; case "t": return kVK_ANSI_T; case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V; case "w": return kVK_ANSI_W; case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y; case "z": return kVK_ANSI_Z
        case "0": return kVK_ANSI_0; case "1": return kVK_ANSI_1; case "2": return kVK_ANSI_2
        case "3": return kVK_ANSI_3; case "4": return kVK_ANSI_4; case "5": return kVK_ANSI_5
        case "6": return kVK_ANSI_6; case "7": return kVK_ANSI_7; case "8": return kVK_ANSI_8
        case "9": return kVK_ANSI_9
        case "left": return kVK_LeftArrow; case "right": return kVK_RightArrow
        case "up": return kVK_UpArrow; case "down": return kVK_DownArrow
        case " ", "space": return kVK_Space
        case "-": return kVK_ANSI_Minus; case "=": return kVK_ANSI_Equal
        case "[": return kVK_ANSI_LeftBracket; case "]": return kVK_ANSI_RightBracket
        case ";": return kVK_ANSI_Semicolon; case "'": return kVK_ANSI_Quote
        case ",": return kVK_ANSI_Comma; case ".": return kVK_ANSI_Period
        case "/": return kVK_ANSI_Slash; case "\\": return kVK_ANSI_Backslash
        case "`": return kVK_ANSI_Grave
        default: return nil
        }
    }
}
