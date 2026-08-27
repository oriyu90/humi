import SwiftUI

/// A thin per-tile status strip: cwd · shell · git branch/dirty · process · clock.
/// Components are toggled globally in Settings › Status Bar. Git + clock refresh on
/// a lazy 12s cadence tied to this view's lifetime (no cost when the bar is off).
struct StatusBarView: View {
    let session: Session
    @ObservedObject var settings: AppSettings

    @State private var git: GitStatus.Info?
    @State private var now = Date()

    private let tick = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

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
        .onReceive(tick) { now = $0; Task { await refreshGit() } }
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
