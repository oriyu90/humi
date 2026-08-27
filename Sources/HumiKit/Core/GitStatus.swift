import Foundation

/// Cheap git branch + dirty lookup for the status bar. Runs `git` off the main
/// thread, caches per directory for a few seconds so multiple tiles in the same
/// repo don't each shell out.
actor GitStatus {
    static let shared = GitStatus()

    struct Info: Sendable { var branch: String; var dirty: Bool }

    private struct Entry { var info: Info?; var at: Date }
    private var cache: [String: Entry] = [:]
    private let ttl: TimeInterval = 5

    func info(for dir: String) async -> Info? {
        if let e = cache[dir], Date().timeIntervalSince(e.at) < ttl { return e.info }
        let result = Self.run(dir)
        cache[dir] = Entry(info: result, at: Date())
        return result
    }

    private static func run(_ dir: String) -> Info? {
        guard let branch = git(["-C", dir, "rev-parse", "--abbrev-ref", "HEAD"]),
              !branch.isEmpty, branch != "HEAD" || git(["-C", dir, "rev-parse", "HEAD"]) != nil
        else { return nil }
        let porcelain = git(["-C", dir, "status", "--porcelain"]) ?? ""
        return Info(branch: branch.isEmpty ? "detached" : branch,
                    dirty: !porcelain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private static func git(_ args: [String]) -> String? {
        guard let exe = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
