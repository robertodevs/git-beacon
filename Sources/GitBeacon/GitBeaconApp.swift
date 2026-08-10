import SwiftUI

@main
struct GitBeaconApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The beacon lives entirely in the status bar item + its popover,
        // both managed by AppDelegate. This Settings scene just gives the
        // app a presence for SwiftPM/Xcode to launch.
        Settings {
            EmptyView()
        }
    }
}
