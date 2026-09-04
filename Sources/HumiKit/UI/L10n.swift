import SwiftUI

/// App localization. macOS auto-selects the best `.lproj` from the user's language
/// list; `Localization` adds a manual override that switches **live** (no relaunch)
/// by pointing string lookups at a specific `.lproj` sub-bundle.
///
/// Views re-render on language change because the override is stored on
/// `AppSettings` (which they already observe) and `AppSettings.appLanguage.didSet`
/// calls `Localization.shared.apply(_:)`, which also bumps `objectWillChange`.
@MainActor
public final class Localization: ObservableObject {
    public static let shared = Localization()

    /// `"system"` or a language code that has an `.lproj`.
    public static let supported = ["system", "ja", "en", "zh-Hans", "pt-BR", "es", "de"]

    private(set) var bundle: Bundle = .humiResources
    private(set) var languageCode = "system"

    private init() { apply(readStoredOverride()) }

    /// The locale to hand SwiftUI via `.environment(\.locale,)` so system controls
    /// (date pickers, etc.) follow the override too.
    var locale: Locale {
        languageCode == "system" ? .current : Locale(identifier: languageCode)
    }

    /// SwiftPM lowercases region/script suffixes when copying resources
    /// (`zh-Hans.lproj` → `zh-hans.lproj`), so look the `.lproj` up case-insensitively.
    private static func lprojBundle(_ code: String) -> Bundle? {
        for candidate in [code, code.lowercased()] {
            if let path = Bundle.humiResources.path(forResource: candidate, ofType: "lproj"),
               let b = Bundle(path: path) { return b }
        }
        return nil
    }

    func apply(_ code: String) {
        let wanted = Self.supported.contains(code) ? code : "system"
        languageCode = wanted
        if wanted == "system" {
            bundle = .humiResources
        } else {
            bundle = Self.lprojBundle(wanted) ?? .humiResources
        }
        // Best-effort for any framework-level strings; SwiftUI text updates come from
        // the objectWillChange below, so no relaunch is needed for our own strings.
        if wanted == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([wanted], forKey: "AppleLanguages")
        }
        objectWillChange.send()
    }

    private func readStoredOverride() -> String {
        UserDefaults.standard.string(forKey: "humiAppLanguage") ?? "system"
    }

    /// Test hook: the parsed `Localizable.strings` for a language code, or `nil` if the
    /// `.lproj` is missing.
    static func loadStrings(_ code: String) -> [String: String]? {
        guard let bundle = lprojBundle(code),
              let stringsPath = bundle.path(forResource: "Localizable", ofType: "strings"),
              let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String]
        else { return nil }
        return dict
    }

    /// Human label for the language picker.
    static func label(for code: String) -> String {
        switch code {
        case "system":  return L("lang.system")
        case "ja":      return "日本語"
        case "en":      return "English"
        case "zh-Hans": return "中文"
        case "pt-BR":   return "Português"
        case "es":      return "Español"
        case "de":      return "Deutsch"
        default:        return code
        }
    }
}

/// Localized string. Falls back to the key itself if missing (so a missing key is
/// visible in the UI and caught by the `L10n` test suite).
@MainActor
public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Localization.shared.bundle.localizedString(forKey: key, value: key, table: nil)
    return args.isEmpty ? format : String(format: format, arguments: args)
}

/// Localized `Text` (verbatim — the string is already resolved, don't re-localize).
@MainActor
public func T(_ key: String, _ args: CVarArg...) -> Text {
    Text(verbatim: L(key, args))
}
