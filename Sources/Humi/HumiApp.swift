import SwiftUI
import HumiKit

@main
struct HumiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var keymap = KeymapStore.shared

    /// A menu button bound to an action's current key chord.
    @ViewBuilder
    private func actionButton(_ action: HumiAction, _ titleKey: String) -> some View {
        let chord = keymap.chord(for: action)
        let button = Button(L(titleKey)) { NotificationCenter.default.post(name: action.notification, object: nil) }
        if let eq = chord.keyEquivalent {
            button.keyboardShortcut(eq, modifiers: chord.swiftUIModifiers)
        } else {
            button
        }
    }

    init() {
        Hum.registerFonts()
        // Live terminals re-render on font-size changes made in Settings.
        AppSettings.shared.onFontSizeChange = { size in
            TerminalRegistry.shared.setFontSize(size)
        }
        // …and on any theme change (family / mode / edit / OS light-dark flip).
        ThemeStore.shared.onChange = {
            TerminalRegistry.shared.applyTheme()
        }
        // …and on terminal-behaviour prefs (option-as-meta, mouse reporting, …).
        AppSettings.shared.onTerminalPrefsChange = {
            TerminalRegistry.shared.applyTerminalPrefs()
        }
        // Rebound shortcuts take effect immediately (menu shortcuts need a relaunch).
        KeymapStore.shared.installLocalMonitor()
        // Global toggle hotkey (Carbon) — kept in sync with its pref.
        HotKeyCenter.bootstrap()
        // Notifications: route taps, and let terminals re-check watchers when prefs change.
        HumiNotifier.bootstrap()
        AppSettings.shared.onAlertPrefsChange = {
            TerminalRegistry.shared.refreshAlertWatchers()
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
        // The toolbar already carries the brand mark, so hide the redundant OS title.
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                actionButton(.newSession, "app.menu.new_session")
                actionButton(.profileLauncher, "launcher.title")
                Divider()
                Button(L("arrangement.save")) {
                    NotificationCenter.default.post(name: .humiSaveArrangement, object: nil)
                }
                Button(L("arrangement.restore")) {
                    NotificationCenter.default.post(name: .humiRestoreArrangement, object: nil)
                }
            }
            CommandGroup(after: .pasteboard) {
                actionButton(.clearBuffer, "app.menu.clear_buffer")
                actionButton(.find, "app.menu.find")
                actionButton(.closeTile, "tile.close")
                actionButton(.restartTile, "tile.restart")
            }
            CommandGroup(after: .toolbar) {
                actionButton(.fontIn, "app.menu.font_in")
                actionButton(.fontOut, "app.menu.font_out")
                actionButton(.fontReset, "app.menu.font_reset")
                Divider()
                actionButton(.splitH, "key.action.splitH")
                actionButton(.splitV, "key.action.splitV")
                actionButton(.growPane, "key.action.growPane")
                actionButton(.shrinkPane, "key.action.shrinkPane")
                actionButton(.equalizeSplits, "key.action.equalizeSplits")
                Divider()
                actionButton(.maximizeTile, "tile.maximize")
                actionButton(.toggleNotes, "toolbar.toggle_notes")
                actionButton(.nextTile, "app.menu.next_tile")
                actionButton(.prevTile, "app.menu.prev_tile")
                actionButton(.focusPaneLeft, "key.action.focusPaneLeft")
                actionButton(.focusPaneRight, "key.action.focusPaneRight")
                actionButton(.focusPaneUp, "key.action.focusPaneUp")
                actionButton(.focusPaneDown, "key.action.focusPaneDown")
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
