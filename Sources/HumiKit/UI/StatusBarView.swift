import SwiftUI
import Combine

/// One process-wide 12s heartbeat for every tile's status bar, instead of a `Timer`
/// per visible tile. Only ticks while at least one status bar is on screen.
@MainActor
final class StatusBarClock: ObservableObject {
    static let shared = StatusBarClock()
    @Published private(set) var now = Date()

    private var timer: AnyCancellable?
    private var subscribers: Set<UUID> = []

    func subscribe(_ id: UUID) {
        guard subscribers.insert(id).inserted else { return }
        guard timer == nil else { return }
        timer = Timer.publish(every: 12, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }

    func unsubscribe(_ id: UUID) {
        guard subscribers.remove(id) != nil else { return }
        if subscribers.isEmpty { timer?.cancel(); timer = nil }
    }

    var subscriberCount: Int { subscribers.count }
}

/// A thin per-tile status strip: cwd · shell · git branch/dirty · process · clock.
/// Components are toggled globally in Settings › Status Bar. Git + clock refresh on
/// a lazy 12s cadence (one shared timer for all tiles; no cost when the bar is off).
struct StatusBarView: View {
    let session: Session
    @ObservedObject var settings: AppSettings
    @ObservedObject private var clock = StatusBarClock.shared

    @State private var git: GitStatus.Info?
    @State private var clockSubscriptionID = UUID()

    private var now: Date { clock.now }

    private var cwd: String? {
        TerminalRegistry.shared.existing(session.id)?.currentDirectory ?? session.workingDirectory
    }

    var body: some View {
        HStack(spacing: Hum.Space.md) {
            if settings.statusCwd, let cwd {
                label("folder", (cwd as NSString).abbreviatingWithTildeInPath)
            }
            if settings.statusShell {
                label("terminal", shellName)
            }
            if settings.statusGit, let git {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: 9))
                    Text(git.branch)
                    if git.dirty { Text("●").foregroundStyle(Hum.coral) }
                }
                .foregroundStyle(Hum.ink2)
            }
            if settings.statusProcess, let proc = foregroundProcess {
                label("gearshape", proc)
            }
            Spacer(minLength: 0)
            if settings.statusClock {
                Text(now, format: .dateTime.hour().minute())
                    .foregroundStyle(Hum.ink2).monospacedDigit()
            }
        }
        .font(Hum.Font.mono(10))
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(.horizontal, Hum.Space.md)
        .padding(.vertical, 3)
        .background(Hum.paper2)
        .task(id: cwd) { await refreshGit() }
        .onChange(of: clock.now) { _, _ in Task { await refreshGit() } }
        .onAppear { clock.subscribe(clockSubscriptionID) }
        .onDisappear { clock.unsubscribe(clockSubscriptionID) }
    }

    private func label(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text)
        }
        .foregroundStyle(Hum.ink2)
    }

    private var shellName: String {
        let inv = ShellResolver.resolve(config: AppSettings.shared.shellConfig)
        return (inv.executable as NSString).lastPathComponent
    }

    private var foregroundProcess: String? {
        guard let c = TerminalRegistry.shared.existing(session.id), c.hasLiveForegroundChild else { return nil }
        return "…"
    }

    private func refreshGit() async {
        guard settings.statusGit, settings.statusBarEnabled, let cwd else { git = nil; return }
        git = await GitStatus.shared.info(for: cwd)
    }
}
