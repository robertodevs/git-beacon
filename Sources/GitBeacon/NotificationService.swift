import Foundation
import UserNotifications

/// Fires local notifications for watched-PR status transitions. Only
/// `checksFailed` and `merged` are notification-worthy — everything else
/// (review requested, checks running, etc.) is visible enough via the
/// status item / popover without interrupting the user.
enum NotificationService {
    /// `UNUserNotificationCenter.current()` throws an uncaught
    /// `NSInternalInconsistencyException` and crashes the process when the
    /// running binary has no bundle identifier — which is exactly what a
    /// raw `swift build`/`swift run` binary is (no Info.plist). Every entry
    /// point below must check this before touching UNUserNotificationCenter
    /// at all; a graceful failure inside a completion handler isn't enough
    /// because the crash happens synchronously on the accessor itself.
    private static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func configure(delegate: UNUserNotificationCenterDelegate) {
        guard isAvailable else {
            NSLog("GitBeacon: notifications unavailable — no app bundle (build/run as a packaged .app to enable them)")
            return
        }
        UNUserNotificationCenter.current().delegate = delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("GitBeacon: notification authorization failed — \(error)")
            }
        }
    }

    static func notify(for pr: WatchedPullRequest) {
        guard isAvailable else { return }

        let content = UNMutableNotificationContent()
        switch pr.status {
        case .checksFailed:
            content.title = "Checks failed"
        case .merged:
            content.title = "PR merged"
        default:
            return
        }
        content.subtitle = "\(pr.repo) #\(pr.number)"
        content.body = pr.title
        content.sound = .default
        content.userInfo = ["url": pr.url.absoluteString]

        // Identifier includes the status so a PR that later transitions to a
        // different notify-worthy status (e.g. re-failing after a fix) gets
        // its own notification rather than being deduped by UNUserNotificationCenter.
        let request = UNNotificationRequest(
            identifier: "\(pr.id)-\(pr.status.rawValue)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("GitBeacon: failed to deliver notification — \(error)")
            }
        }
    }
}
