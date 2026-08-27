import SwiftUI
import HumiKit

@main
struct HumiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Hum.registerFonts()
        // Live terminals re-render on font-size changes made in Settings.
        AppSettings.shared.onFontSizeChange = { size in
            TerminalRegistry.shared.setFontSize(size)
        }
    }

    var body: some Scene {
        // Single unique window: two windows would each own a SessionStore/NotesStore
        // racing over the same files while sharing one TerminalRegistry.
        Window("Humi", id: "humi-main") {
            RootView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1120, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("app.menu.new_session")) { NotificationCenter.default.post(name: .humiNewSession, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command])
            }
            CommandGroup(after: .pasteboard) {
                Button(L("app.menu.clear_buffer")) { NotificationCenter.default.post(name: .humiClearBuffer, object: nil) }
                    .keyboardShortcut("k", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

/// Owns process + note lifecycle across app shutdown: every live terminal child is
/// torn down cleanly (SIGTERM → SIGKILL, reaped) and the notes buffer is flushed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillResignActive(_ notification: Notification) {
        MainActor.assumeIsolated { NotesStore.shared.flush() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            NotesStore.shared.flush()
            // Blocking teardown: this callback returns and the process exits, so a
            // deferred reap would never run.
            TerminalRegistry.shared.terminateAllSync()
        }
    }
}
