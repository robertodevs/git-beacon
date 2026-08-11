import AppKit
import SwiftUI

/// A plain NSWindow hosting SettingsView, managed independently of the
/// app's SwiftUI Settings scene — accessory apps (no Dock icon, no app
/// menu) can't rely on the automatic Cmd+, handling, so this is opened
/// directly from the status item's right-click menu instead.
final class SettingsWindowController: NSWindowController {
    convenience init(onSave: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "GitBeacon Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView(onSave: onSave))
        window.center()

        self.init(window: window)
    }
}
