import Foundation
import Darwin

/// ZIP export / import for the notes sidebar, for moving notes between machines.
///
/// The archive is plain and inspectable: a `manifest.json` at the root plus one
/// `NN--slug.md` per note (`NN` = order, `slug` = a filesystem-safe title). Import
/// reads the manifest; a hand-made zip of loose `.md` files also works (each becomes
/// a note titled from its filename).
///
/// Archiving is done with `/usr/bin/ditto` (a system tool, already used by the build
/// scripts) so there's no third-party dependency and the output is a standard PKZip.
public enum NotesArchive {
    static let manifestName = "manifest.json"

    public enum ArchiveError: LocalizedError {
        case ditto(Int32, String)
        case timedOut
        case noNotesFound
        case notReadable

        public var errorDescription: String? {
            switch self {
            case let .ditto(code, msg): return "ditto exited \(code): \(msg)"
            case .timedOut:             return "the archive operation timed out"
            case .noNotesFound:         return "no notes found in the archive"
            case .notReadable:          return "the file could not be read"
            }
        }
    }

    private struct ManifestEntry: Codable {
        var id: UUID
        var title: String
        var file: String
        var createdAt: Double
        var modifiedAt: Double
    }

    // MARK: export

    /// Write `notes` to a ZIP at `dest` (overwrites).
    public static func export(_ notes: [NoteDoc], to dest: URL) throws {
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("humi-notes-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }

        var manifest: [ManifestEntry] = []
        for (i, note) in notes.enumerated() {
            let file = String(format: "%02d--%@.md", i + 1, slug(note.title))
            try Data(note.text.utf8).write(to: stage.appendingPathComponent(file), options: .atomic)
            manifest.append(ManifestEntry(id: note.id, title: note.title, file: file,
                                          createdAt: note.createdAt, modifiedAt: note.modifiedAt))
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(manifest).write(to: stage.appendingPathComponent(manifestName), options: .atomic)

        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        // Archive the *contents* of `stage` (no enclosing folder in the zip).
        try runDitto(["-c", "-k", "--sequesterRsrc", stage.path, dest.path])
    }

    // MARK: import

    /// Read notes from a ZIP at `src`. Order follows the manifest, else filename order.
    public static func read(from src: URL) throws -> [NoteDoc] {
        let fm = FileManager.default
        let out = fm.temporaryDirectory.appendingPathComponent("humi-notes-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: out) }

        try runDitto(["-x", "-k", src.path, out.path])

        // A zip can extract to `out/` directly or to `out/<single-folder>/`.
        let root: URL = {
            let items = (try? fm.contentsOfDirectory(at: out, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            if items.count == 1, (try? items[0].resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                return items[0]
            }
            return out
        }()

        if let manifestData = try? Data(contentsOf: root.appendingPathComponent(manifestName)),
           let manifest = try? JSONDecoder().decode([ManifestEntry].self, from: manifestData) {
            let notes: [NoteDoc] = manifest.compactMap { e in
                guard let body = try? String(contentsOf: root.appendingPathComponent(e.file), encoding: .utf8)
                else { return nil }
                return NoteDoc(id: e.id, title: e.title, text: body,
                               createdAt: e.createdAt, modifiedAt: e.modifiedAt)
            }
            guard !notes.isEmpty else { throw ArchiveError.noNotesFound }
            return notes
        }

        // Fallback: loose .md files, titled from their filenames.
        let mdFiles = ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let notes: [NoteDoc] = mdFiles.compactMap { url in
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return NoteDoc(title: url.deletingPathExtension().lastPathComponent, text: body)
        }
        guard !notes.isEmpty else { throw ArchiveError.noNotesFound }
        return notes
    }

    // MARK: helpers

    /// ASCII-only, filesystem-safe stem for a note file. Non `[A-Za-z0-9]` runs
    /// collapse to a single `-` (so CJK titles fall back to `note`).
    static func slug(_ title: String) -> String {
        let scalars = title.unicodeScalars.map { s -> Character in
            let ok = (s.value >= 48 && s.value <= 57)   // 0-9
                || (s.value >= 65 && s.value <= 90)      // A-Z
                || (s.value >= 97 && s.value <= 122)     // a-z
            return ok ? Character(s) : "-"
        }
        let s = String(scalars)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let trimmed = String(s.prefix(40))
        return trimmed.isEmpty ? "note" : trimmed
    }

    private static func runDitto(_ args: [String]) throws {
        let result = try runProcess(executable: URL(fileURLWithPath: "/usr/bin/ditto"),
                                    arguments: args,
                                    timeout: 30)
        if result.status != 0 {
            throw ArchiveError.ditto(result.status, result.stderr)
        }
    }

    /// Runs an archive helper without letting either output pipe block the child.
    /// Internal so the deadlock and timeout paths can be covered by the self-test.
    static func runProcess(executable: URL,
                           arguments: [String],
                           timeout: TimeInterval) throws -> (status: Int32, stderr: String) {
        let proc = Process()
        proc.executableURL = executable
        proc.arguments = arguments
        let err = Pipe()
        proc.standardError = err
        // Archive output is never consumed. A pipe here can fill and deadlock.
        proc.standardOutput = FileHandle.nullDevice

        final class DataBox: @unchecked Sendable {
            private let lock = NSLock()
            private var value = Data()
            func set(_ data: Data) { lock.lock(); value = data; lock.unlock() }
            func get() -> Data { lock.lock(); defer { lock.unlock() }; return value }
        }

        let stderrData = DataBox()
        let stderrRead = DispatchGroup()
        stderrRead.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData.set(err.fileHandleForReading.readDataToEndOfFile())
            stderrRead.leave()
        }

        let terminated = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in terminated.signal() }
        do {
            try proc.run()
        } catch {
            try? err.fileHandleForWriting.close()
            _ = stderrRead.wait(timeout: .now() + 1)
            throw error
        }
        // The child owns a duplicated descriptor. Closing the parent's writer lets
        // the background reader observe EOF as soon as the child exits.
        try? err.fileHandleForWriting.close()

        var didTimeOut = false
        if terminated.wait(timeout: .now() + max(0.01, timeout)) == .timedOut {
            didTimeOut = true
            proc.terminate()
            if terminated.wait(timeout: .now() + 0.5) == .timedOut {
                kill(proc.processIdentifier, SIGKILL)
                _ = terminated.wait(timeout: .now() + 1)
            }
        }

        if stderrRead.wait(timeout: .now() + 1) == .timedOut {
            try? err.fileHandleForReading.close()
            throw ArchiveError.timedOut
        }
        if didTimeOut { throw ArchiveError.timedOut }

        let message = String(data: stderrData.get(), encoding: .utf8) ?? ""
        return (proc.terminationStatus,
                message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
