import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var indicatorView: BeaconIndicatorView?
    private let popover = NSPopover()
    private let state = BeaconState()
    private var cancellable: AnyCancellable?
    private var settingsWindowController: SettingsWindowController?

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
        item.button?.action = #selector(handleStatusItemClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Pops up a standalone NSMenu on right-click without permanently
    /// attaching it to the status item — an attached menu would swallow
    /// left-clicks too and break the popover toggle above.
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit GitBeacon", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshNow() {
        Task { await state.refresh() }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(onSave: { [weak self] in
                self?.state.startPolling()
            })
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
