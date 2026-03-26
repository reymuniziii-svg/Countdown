import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let calendarService: CalendarService
    private let audioManager: AudioManager
    private var window: NSWindow?

    init(calendarService: CalendarService, audioManager: AudioManager) {
        self.calendarService = calendarService
        self.audioManager = audioManager
    }

    func show() {
        if window == nil {
            let rootView = SettingsView(
                calendarService: calendarService,
                audioManager: audioManager
            )

            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 450, height: 400))
            window.title = "Countdown Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
