import AppKit

/// Opens whatever a terminal string points at: a URL in the browser, an existing
/// file/dir in Finder, or `path:line` in a configured editor.
enum PathActioner {

    enum Kind: Equatable { case url, fileLine(path: String, line: Int), path(String), unknown }

    /// Classify a candidate string (a selection, or a ⌘-clicked link).
    static func classify(_ raw: String, relativeTo cwd: String?) -> Kind {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return .unknown }

        if let url = URL(string: s), let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp", "mailto", "file", "ssh"].contains(scheme) {
            return .url
        }

        // path:line[:col]
        if let m = s.range(of: #"^(.+?):(\d+)(?::\d+)?$"#, options: .regularExpression) {
            let matched = String(s[m])
            let parts = matched.split(separator: ":")
            if parts.count >= 2, let line = Int(parts[1]) {
                let path = resolve(String(parts[0]), cwd: cwd)
                if FileManager.default.fileExists(atPath: path) {
                    return .fileLine(path: path, line: line)
                }
            }
        }

        let path = resolve(s, cwd: cwd)
        if FileManager.default.fileExists(atPath: path) { return .path(path) }
        return .unknown
    }

    private static func resolve(_ path: String, cwd: String?) -> String {
        var p = (path as NSString).expandingTildeInPath
        if !p.hasPrefix("/"), let cwd { p = (cwd as NSString).appendingPathComponent(p) }
        return (p as NSString).standardizingPath
    }

    /// Act on `raw`. Returns false when nothing actionable was found.
    @discardableResult @MainActor
    static func open(_ raw: String, cwd: String?, editorCommand: String) -> Bool {
        switch classify(raw, relativeTo: cwd) {
        case .url:
            if let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                NSWorkspace.shared.open(url); return true
            }
            return false
        case let .fileLine(path, line):
            if runEditor(editorCommand, file: path, line: line) { return true }
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            return true
        case let .path(path):
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            if isDir.boolValue { NSWorkspace.shared.open(url) }
            else { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            return true
        case .unknown:
            return false
        }
    }

    /// Run e.g. `code -g {file}:{line}`. Returns false if the executable isn't found.
    @discardableResult
    static func runEditor(_ template: String, file: String, line: Int) -> Bool {
        let filled = template
            .replacingOccurrences(of: "{file}", with: file)
            .replacingOccurrences(of: "{line}", with: String(line))
        var argv = filled.split(separator: " ").map(String.init)
        guard !argv.isEmpty else { return false }
        let exe = argv.removeFirst()
        guard let resolved = which(exe) else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: resolved)
        p.arguments = argv
        do { try p.run(); return true } catch { return false }
    }

    private static func which(_ name: String) -> String? {
        if name.hasPrefix("/") { return FileManager.default.isExecutableFile(atPath: name) ? name : nil }
        let dirs = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin")
            .split(separator: ":").map(String.init)
        for d in dirs {
            let candidate = (d as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
