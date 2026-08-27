import Foundation

/// Small JSON/text store under ~/Library/Application Support/Humi.
/// All writes are atomic; reads never throw (missing file → nil / default).
enum Persistence {
    static let directoryName = "Humi"

    /// All disk writes go through this serial queue, off the main thread.
    private static let ioQueue = DispatchQueue(label: "com.studiorizi.humi.io", qos: .utility)

    private static let _baseURL: URL = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = root.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var baseURL: URL { _baseURL }

    static func url(_ name: String) -> URL { baseURL.appendingPathComponent(name) }

    static func readData(_ name: String) -> Data? {
        try? Data(contentsOf: url(name))
    }

    /// Asynchronous atomic write on `ioQueue`. Safe to call from the main thread.
    static func writeData(_ data: Data, to name: String) {
        let target = url(name)
        ioQueue.async {
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                NSLog("Humi: failed to write \(name): \(error.localizedDescription)")
            }
        }
    }

    /// Synchronous atomic write — used only on app-terminate flush paths.
    static func writeDataSync(_ data: Data, to name: String) {
        ioQueue.sync {
            try? data.write(to: url(name), options: .atomic)
        }
    }

    static func readString(_ name: String) -> String? {
        guard let data = readData(name) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func writeString(_ string: String, to name: String) {
        writeData(Data(string.utf8), to: name)
    }

    static func writeStringSync(_ string: String, to name: String) {
        writeDataSync(Data(string.utf8), to: name)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = readData(name) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T, to name: String, sync: Bool = false) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        if sync { writeDataSync(data, to: name) } else { writeData(data, to: name) }
    }
}
