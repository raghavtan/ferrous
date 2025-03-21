import Cocoa
import SwiftUI

/// Controller for the status bar item and popover
final class StatusBarController {
    /// The status bar item
    private var statusItem: NSStatusItem

    /// The popover that appears when clicking the status bar item
    private var popover: NSPopover

    /// Event monitor for detecting clicks outside the popover
    private var eventMonitor: EventMonitor?

    /// Logger instance
    private let logger = FerrousLogger.app

    /// Initializes the status bar controller
    init() {
        FerrousLogger.shared.debug("Initializing status bar controller", log: logger)

        // Create and configure the popover first
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainMenuView())

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure the status bar button
        if let button = statusItem.button {
            button.title = "Ferrous"
            button.action = #selector(togglePopover(_:))
            button.target = self  // Now safe to use self since popover is initialized
        }

        // Set up event monitor to detect clicks outside the popover
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover(event)
        }
        eventMonitor?.start()

        FerrousLogger.shared.debug("Status bar controller initialized", log: logger)
    }

    /// Toggles the popover visibility
    /// - Parameter sender: The sender of the action
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    /// Shows the popover
    /// - Parameter sender: The sender of the action
    func showPopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            FerrousLogger.shared.warning("Status item has no button", log: logger)
            return
        }

        FerrousLogger.shared.debug("Showing popover", log: logger)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        eventMonitor?.start()
    }

    /// Closes the popover
    /// - Parameter sender: The sender of the action
    func closePopover(_ sender: Any?) {
        FerrousLogger.shared.debug("Closing popover", log: logger)
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    /// Deinitializer
    deinit {
        eventMonitor?.stop()
        FerrousLogger.shared.debug("Status bar controller deinitialized", log: logger)
    }
}

/// Monitors mouse events outside the popover
final class EventMonitor {
    /// The event mask to monitor
    private let mask: NSEvent.EventTypeMask

    /// The handler to call when an event occurs
    private let handler: (NSEvent?) -> Void

    /// The monitor object
    private var monitor: Any?

    /// Creates a new event monitor
    /// - Parameters:
    ///   - mask: The event mask to monitor
    ///   - handler: The handler to call when an event occurs
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    /// Starts monitoring events
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    /// Stops monitoring events
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    /// Deinitializer
    deinit {
        stop()
    }
}