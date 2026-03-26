import SwiftUI

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let calendarService: CalendarService
    let audioManager: AudioManager
    let meetingMonitor: MeetingMonitor
    let overlayCoordinator: OverlayCoordinator
    let statusBarManager: StatusBarManager
    let settingsWindowController: SettingsWindowController

    private var hasStarted = false

    private init() {
        let calendar = CalendarService()
        let audio = AudioManager()
        let monitor = MeetingMonitor(calendarService: calendar, audioManager: audio)

        calendarService = calendar
        audioManager = audio
        meetingMonitor = monitor
        overlayCoordinator = OverlayCoordinator(monitor: monitor)
        statusBarManager = StatusBarManager()
        settingsWindowController = SettingsWindowController(
            calendarService: calendar,
            audioManager: audio
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        overlayCoordinator.startObserving()
        statusBarManager.configure(
            monitor: meetingMonitor,
            calendarService: calendarService
        )
        meetingMonitor.start()

        Task {
            await calendarService.prepareForLaunch()
        }
    }
}
