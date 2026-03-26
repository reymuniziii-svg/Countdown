import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let hasPresentedLaunchPreviewKey = "hasPresentedLaunchPreview"

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let appController = AppController.shared
            appController.start()
            statusItemController = StatusItemController(
                calendarService: appController.calendarService,
                meetingMonitor: appController.meetingMonitor,
                audioManager: appController.audioManager,
                statusBarManager: appController.statusBarManager,
                onOpenSettings: { [weak appController] in
                    appController?.settingsWindowController.show()
                }
            )

            let shouldRevealWindow =
                !UserDefaults.standard.bool(forKey: hasPresentedLaunchPreviewKey) ||
                !appController.calendarService.hasCalendarAccess

            if shouldRevealWindow {
                UserDefaults.standard.set(true, forKey: hasPresentedLaunchPreviewKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    AppController.shared.settingsWindowController.show()
                }
            }
        }
    }
}
