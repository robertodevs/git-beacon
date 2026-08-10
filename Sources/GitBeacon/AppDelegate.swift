import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var indicatorView: BeaconIndicatorView?
    private let popover = NSPopover()
    private let state = BeaconState()
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: 22)
        let indicator = BeaconIndicatorView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        item.button?.addSubview(indicator)
        indicator.frame = NSRect(
            x: (item.button!.bounds.width - 16) / 2,
            y: (item.button!.bounds.height - 16) / 2,
            width: 16,
            height: 16
        )
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        indicatorView = indicator

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(rootView: TimelineView(state: state))

        cancellable = state.$pullRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.indicatorView?.update(status: self?.state.overallStatus)
            }

        state.startPolling()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
