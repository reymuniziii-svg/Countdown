import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private let onOpenSettings: () -> Void

    init(
        calendarService: CalendarService,
        meetingMonitor: MeetingMonitor,
        audioManager: AudioManager,
        statusBarManager: StatusBarManager,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        super.init()

        let contentView = MenuBarView(
            calendarService: calendarService,
            meetingMonitor: meetingMonitor,
            audioManager: audioManager,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 480)
        popover.contentViewController = NSHostingController(rootView: contentView)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
            button.appearsDisabled = false
        }

        statusBarManager.$displayText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.applyTitle(text)
            }
            .store(in: &cancellables)

        applyTitle(statusBarManager.displayText)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(relativeTo: button)
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        showPopover(relativeTo: button)
    }

    func openSettingsWindow() {
        openSettings()
    }

    private func applyTitle(_ title: String) {
        guard let button = statusItem.button else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]

        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.toolTip = title
    }

    private func openSettings() {
        popover.performClose(nil)
        onOpenSettings()
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
