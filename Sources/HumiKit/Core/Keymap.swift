import SwiftUI
import AppKit

/// Actions that can be bound to a key chord. Raw values are stable persistence keys.
public enum HumiAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case newSession, closeTile, restartTile, maximizeTile, clearBuffer
    case find, fontIn, fontOut, fontReset, nextTile, prevTile, toggleNotes, profileLauncher
    // v1.2 — pane tree
    case splitH, splitV
    case focusPaneLeft, focusPaneRight, focusPaneUp, focusPaneDown
    case equalizeSplits

    public var id: String { rawValue }

    public var notification: Notification.Name {
        switch self {
        case .newSession:      return .humiNewSession
        case .closeTile:       return .humiCloseTile
        case .restartTile:     return .humiRestartTile
        case .maximizeTile:    return .humiMaximizeTile
        case .clearBuffer:     return .humiClearBuffer
        case .find:            return .humiFind
        case .fontIn:          return .humiFontIn
        case .fontOut:         return .humiFontOut
        case .fontReset:       return .humiFontReset
        case .nextTile:        return .humiNextTile
        case .prevTile:        return .humiPrevTile
        case .toggleNotes:     return .humiToggleNotes
        case .profileLauncher: return .humiProfileLauncher
        case .splitH:          return .humiSplitH
        case .splitV:          return .humiSplitV
        case .focusPaneLeft:   return .humiFocusPaneLeft
        case .focusPaneRight:  return .humiFocusPaneRight
        case .focusPaneUp:     return .humiFocusPaneUp
        case .focusPaneDown:   return .humiFocusPaneDown
        case .equalizeSplits:  return .humiEqualizeSplits
        }
    }

    @MainActor var label: String { L("key.action.\(rawValue)") }
}

/// A key + modifier combination, Codable and convertible to a SwiftUI shortcut.
public struct KeyChord: Codable, Equatable, Sendable {
    /// A single character ("n", "+", "0") or a special token ("left", "right", "up", "down").
    public var key: String
    /// `NSEvent.ModifierFlags.rawValue` masked to device-independent flags.
    public var modifiers: UInt

    public init(key: String, modifiers: UInt) { self.key = key; self.modifiers = modifiers }

    var eventModifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    public var swiftUIModifiers: EventModifiers {
        var m: EventModifiers = []
        let f = eventModifiers
        if f.contains(.command) { m.insert(.command) }
        if f.contains(.option) { m.insert(.option) }
        if f.contains(.control) { m.insert(.control) }
        if f.contains(.shift) { m.insert(.shift) }
        return m
    }

    public var keyEquivalent: KeyEquivalent? {
        switch key {
        case "left":  return .leftArrow
        case "right": return .rightArrow
        case "up":    return .upArrow
        case "down":  return .downArrow
        default:      return key.first.map { KeyEquivalent($0) }
        }
    }

    public var shortcut: KeyboardShortcut? {
        keyEquivalent.map { KeyboardShortcut($0, modifiers: swiftUIModifiers) }
    }

    /// "⌘⌥N" style display.
    public var display: String {
        var s = ""
        let f = eventModifiers
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option) { s += "⌥" }
        if f.contains(.shift) { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        switch key {
        case "left": s += "←"; case "right": s += "→"; case "up": s += "↑"; case "down": s += "↓"
        default: s += key.uppercased()
        }
        return s
    }

    static func from(event: NSEvent) -> KeyChord? {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return nil }   // require at least one modifier
        let key: String
        switch event.keyCode {
        case 123: key = "left"; case 124: key = "right"; case 126: key = "up"; case 125: key = "down"
        default:
            guard let chars = event.charactersIgnoringModifiers?.lowercased(), let c = chars.first,
                  c.isLetter || c.isNumber || "+-=[]\\;',./`".contains(c) else { return nil }
            key = String(c)
        }
        return KeyChord(key: key, modifiers: mods.rawValue)
    }
}

/// The action → chord map, persisted to `keymap.json`. Unmapped actions fall back to defaults.
@MainActor
public final class KeymapStore: ObservableObject {
    public static let shared = KeymapStore()
    static let fileName = "keymap.json"

    @Published private(set) var map: [String: KeyChord] = [:]

    static let cmd = NSEvent.ModifierFlags.command.rawValue
    static let cmdOpt = (NSEvent.ModifierFlags.command.union(.option)).rawValue
    static let cmdShift = (NSEvent.ModifierFlags.command.union(.shift)).rawValue
    static let cmdCtrl = (NSEvent.ModifierFlags.command.union(.control)).rawValue

    static let defaults: [HumiAction: KeyChord] = [
        .newSession:   KeyChord(key: "n", modifiers: cmd),
        .closeTile:    KeyChord(key: "w", modifiers: cmd),
        .restartTile:  KeyChord(key: "r", modifiers: cmd),
        .maximizeTile: KeyChord(key: "m", modifiers: cmd),
        .clearBuffer:  KeyChord(key: "k", modifiers: cmd),
        .find:         KeyChord(key: "f", modifiers: cmd),
        .fontIn:       KeyChord(key: "+", modifiers: cmd),
        .fontOut:      KeyChord(key: "-", modifiers: cmd),
        .fontReset:    KeyChord(key: "0", modifiers: cmd),
        .nextTile:     KeyChord(key: "right", modifiers: cmdOpt),
        .prevTile:     KeyChord(key: "left", modifiers: cmdOpt),
        .toggleNotes:  KeyChord(key: "s", modifiers: cmdOpt),
        .profileLauncher: KeyChord(key: "p", modifiers: cmdOpt),
        .splitH:       KeyChord(key: "d", modifiers: cmd),
        .splitV:       KeyChord(key: "d", modifiers: cmdShift),
        .focusPaneLeft:  KeyChord(key: "left", modifiers: cmdCtrl),
        .focusPaneRight: KeyChord(key: "right", modifiers: cmdCtrl),
        .focusPaneUp:    KeyChord(key: "up", modifiers: cmdCtrl),
        .focusPaneDown:  KeyChord(key: "down", modifiers: cmdCtrl),
        .equalizeSplits: KeyChord(key: "=", modifiers: cmdOpt),
    ]

    private var localMonitor: Any?

    private init() {
        if let saved = Persistence.decode([String: KeyChord].self, from: Self.fileName) {
            map = saved
        }
    }

    /// Watch key-downs so a *rebound* chord takes effect without an app restart —
    /// SwiftUI's `.commands` shortcuts only re-evaluate on relaunch. Chords still set to
    /// their built-in default are left for the menu to handle (no double-invoke).
    public func installLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let chord = KeyChord.from(event: event) else { return event }
            for action in HumiAction.allCases where self.chord(for: action) == chord {
                if Self.defaults[action] == chord { return event }   // menu already covers it
                NotificationCenter.default.post(name: action.notification, object: nil)
                return nil
            }
            return event
        }
    }

    public func chord(for action: HumiAction) -> KeyChord {
        map[action.rawValue] ?? Self.defaults[action] ?? KeyChord(key: "?", modifiers: 0)
    }

    func set(_ action: HumiAction, _ chord: KeyChord?) {
        if let chord { map[action.rawValue] = chord } else { map.removeValue(forKey: action.rawValue) }
        Persistence.encode(map, to: Self.fileName)
        objectWillChange.send()
    }

    func resetAll() {
        map = [:]
        Persistence.encode(map, to: Self.fileName)
        objectWillChange.send()
    }

    /// Actions whose chord collides with `chord` (excluding `action` itself).
    func conflicts(_ chord: KeyChord, excluding action: HumiAction) -> [HumiAction] {
        HumiAction.allCases.filter { $0 != action && self.chord(for: $0) == chord }
    }

    func exportMap(to url: URL) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(map).write(to: url, options: .atomic)
    }
    func importMap(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode([String: KeyChord].self, from: data) else { return }
        map = m
        Persistence.encode(map, to: Self.fileName)
        objectWillChange.send()
    }
}
