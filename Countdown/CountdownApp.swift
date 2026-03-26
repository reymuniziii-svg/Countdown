import Combine
import SwiftUI

@main
struct CountdownApp: App {
    @StateObject private var calendarService: CalendarService
    @StateObject private var audioManager: AudioManager
    @StateObject private var meetingMonitor: MeetingMonitor
    @StateObject private var overlayCoordinator: OverlayCoordinator

    init() {
        let calendar = CalendarService()
        let audio = AudioManager()
        let monitor = MeetingMonitor(calendarService: calendar, audioManager: audio)
        let coordinator = OverlayCoordinator(monitor: monitor)
        _calendarService = StateObject(wrappedValue: calendar)
        _audioManager = StateObject(wrappedValue: audio)
        _meetingMonitor = StateObject(wrappedValue: monitor)
        _overlayCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                calendarService: calendarService,
                meetingMonitor: meetingMonitor,
                audioManager: audioManager
            )
            .onAppear {
                Task {
                    await calendarService.requestAccess()
                    calendarService.startMonitoring()
                    meetingMonitor.start()
                    overlayCoordinator.startObserving()
                }
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(calendarService: calendarService, audioManager: audioManager)
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let nextEvent = calendarService.events.first(where: { $0.timeUntilStart > 0 })
        if let event = nextEvent {
            let text = "\(truncate(event.title, to: 20)) in \(event.formattedTimeUntil)"
            Label(text, systemImage: "calendar.badge.clock")
        } else {
            Label("Countdown", systemImage: "calendar.badge.clock")
        }
    }

    private func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length { return string }
        return String(string.prefix(length - 1)) + "..."
    }
}

@MainActor
final class OverlayCoordinator: ObservableObject {
    private let monitor: MeetingMonitor
    private let windowController = OverlayWindowController()
    private var cancellable: AnyCancellable?

    init(monitor: MeetingMonitor) {
        self.monitor = monitor
    }

    func startObserving() {
        cancellable = monitor.$shouldShowOverlay
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                guard let self else { return }
                if shouldShow, let event = monitor.activeOverlayEvent {
                    windowController.show(
                        event: event,
                        countdownSeconds: monitor.countdownSeconds,
                        monitor: monitor,
                        onDismiss: { [weak self] in self?.monitor.dismiss() },
                        onSnooze: { [weak self] in self?.monitor.snooze() },
                        onJoin: { [weak self] in self?.monitor.joinMeeting() }
                    )
                } else {
                    windowController.close()
                }
            }
    }
}
