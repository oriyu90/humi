import Foundation

private final class HumiBundleToken {}

extension Bundle {
    /// HumiKit's resource bundle (bundled fonts + `.lproj` string tables), resolved
    /// resiliently.
    ///
    /// SwiftPM's generated `Bundle.module` accessor on the Command Line Tools toolchain
    /// only checks two paths: `Bundle.main.bundleURL/Humi_HumiKit.bundle` (the `.app`
    /// *root*, not `Contents/Resources/`) and a hardcoded build-machine path. A
    /// hand-assembled `.app` — which is how Humi ships, since there's no Xcode here —
    /// puts the bundle in `Contents/Resources/`, where `Bundle.module` never looks, so it
    /// `fatalError`s in `registerFonts()` before the first window. This resolver tries the
    /// standard locations in order and falls back to the framework bundle itself.
    static let humiResources: Bundle = {
        let name = "Humi_HumiKit.bundle"
        let token = Bundle(for: HumiBundleToken.self)
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(name),   // .app/Contents/Resources/
            Bundle.main.bundleURL.appendingPathComponent(name),      // .app root (SwiftPM default)
            token.resourceURL?.appendingPathComponent(name),
            token.bundleURL.appendingPathComponent(name),
            token.bundleURL.deletingLastPathComponent().appendingPathComponent(name),
        ]
        for url in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: url.path) {
            if let bundle = Bundle(url: url) { return bundle }
        }
        // Last resort: resources may have been flattened into the framework bundle.
        return token
    }()
}
