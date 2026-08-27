import Foundation

/// The user's profiles + which one new sessions use by default. Persisted to
/// `profiles.json`. There is no hidden built-in profile — an absent `defaultProfileID`
/// (or a session with no `profileID`) simply means "use the global settings".
@MainActor
public final class ProfileStore: ObservableObject {
    public static let shared = ProfileStore()
    static let fileName = "profiles.json"

    @Published var profiles: [Profile] = []
    @Published var defaultProfileID: UUID?

    private struct Disk: Codable { var profiles: [Profile]; var defaultProfileID: UUID? }

    private init() {
        if let d = Persistence.decode(Disk.self, from: Self.fileName) {
            profiles = d.profiles
            defaultProfileID = d.defaultProfileID
        }
    }

    func profile(_ id: UUID?) -> Profile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    var defaultProfile: Profile? { profile(defaultProfileID) }

    // MARK: mutations

    func add(_ p: Profile) { profiles.append(p); persist() }

    func update(_ p: Profile) {
        guard let i = profiles.firstIndex(where: { $0.id == p.id }) else { return }
        profiles[i] = p; persist()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        if defaultProfileID == id { defaultProfileID = nil }
        persist()
    }

    func setDefault(_ id: UUID?) { defaultProfileID = id; persist() }

    @discardableResult
    func duplicate(_ p: Profile) -> Profile {
        var copy = p
        copy.id = UUID()
        copy.name = uniqueName(base: p.name)
        profiles.append(copy); persist()
        return copy
    }

    func uniqueName(base: String) -> String {
        var name = "\(base) copy"; var n = 2
        let taken = Set(profiles.map(\.name))
        while taken.contains(name) { name = "\(base) copy \(n)"; n += 1 }
        return name
    }

    private func persist() {
        Persistence.encode(Disk(profiles: profiles, defaultProfileID: defaultProfileID), to: Self.fileName)
        objectWillChange.send()
    }

    // MARK: import / export

    func export(_ p: Profile, to url: URL) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(p).write(to: url, options: .atomic)
    }

    @discardableResult
    func importProfile(from url: URL) -> Profile? {
        guard let data = try? Data(contentsOf: url), var p = Profile.decode(data) else { return nil }
        p.id = UUID()
        p.name = Set(profiles.map(\.name)).contains(p.name) ? uniqueName(base: p.name) : p.name
        profiles.append(p); persist()
        return p
    }
}
