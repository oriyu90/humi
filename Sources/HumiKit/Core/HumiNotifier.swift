import AppKit
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` for Humi's optional alerts (long
/// command finished, terminal bell, output match). Authorization is requested lazily
/// the first time something wants to post. Tapping a notification focuses its pane.
@MainActor
public final class HumiNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HumiNotifier()

    private var authorized = false
    private var asked = false

    /// Posted (object: session UUID) when the user taps a Humi notification.
    static let focusRequest = Notification.Name("humi.notification.focusRequest")

    /// Call once at launch so notification taps are routed even on a cold start.
    public static func bootstrap() {
        UNUserNotificationCenter.current().delegate = shared
    }

    private func withAuth(_ body: @escaping () -> Void) {
        if authorized { body(); return }
        if asked { return }
        asked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            Task { @MainActor in
                self.authorized = ok
                if ok { body() }
            }
        }
    }

    func post(title: String, body: String, sessionID: UUID?) {
        withAuth {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let sessionID { content.userInfo = ["sessionID": sessionID.uuidString] }
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                   didReceive response: UNNotificationResponse,
                                                   withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let raw = info["sessionID"] as? String
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            if let raw, let id = UUID(uuidString: raw) {
                NotificationCenter.default.post(name: HumiNotifier.focusRequest, object: id)
            }
        }
        completionHandler()
    }
}
