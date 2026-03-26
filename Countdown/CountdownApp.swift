import Combine
import SwiftUI

@main
struct CountdownApp: App {
    @StateObject private var calendarService: CalendarService
    @StateObject private var audioManager: AudioManager
    @StateObject private var meetingMonitor: MeetingMonitor
    @StateObject private var overlayCoordinator: OverlayCoordinator
    @StateObject private var statusBarManager: StatusBarManager

    init() {
        let calendar = CalendarService()
        let audio = AudioManager()
        let monitor = MeetingMonitor(calendarService: calendar, audioManager: audio)
        let coordinator = OverlayCoordinator(monitor: monitor)
        let statusBar = StatusBarManager()
        _calendarService = StateObject(wrappedValue: calendar)
        _audioManager = StateObject(wrappedValue: audio)
        _meetingMonitor = StateObject(wrappedValue: monitor)
        _overlayCoordinator = StateObject(wrappedValue: coordinator)
        _statusBarManager = StateObject(wrappedValue: statusBar)
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
                    statusBarManager.configure(
                        monitor: meetingMonitor,
                        calendarService: calendarService
                    )
                }
            }
        } label: {
            StatusBarLabelBridge(statusBarManager: statusBarManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(calendarService: calendarService, audioManager: audioManager)
        }
    }
}

// MARK: - StatusBarManager (computes the title string reactively)

@MainActor
final class StatusBarManager: ObservableObject {
    @Published var displayText: String = "Countdown"
    @Published var iconName: String = "calendar.badge.clock"

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    func configure(monitor: MeetingMonitor, calendarService: CalendarService) {
        // React to countdown ticks
        monitor.$countdownSeconds
            .combineLatest(monitor.$activeOverlayEvent)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak calendarService] seconds, event in
                self?.update(seconds: seconds, event: event, calendarService: calendarService)
            }
            .store(in: &cancellables)

        // React to calendar events loading
        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self, weak monitor] _ in
                guard let monitor else { return }
                self?.update(
                    seconds: monitor.countdownSeconds,
                    event: monitor.activeOverlayEvent,
                    calendarService: calendarService
                )
            }
            .store(in: &cancellables)

        // Refresh idle text every 30s ("in 23m" → "in 22m")
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self, weak monitor, weak calendarService] _ in
            Task { @MainActor in
                guard let monitor else { return }
                self?.update(
                    seconds: monitor.countdownSeconds,
                    event: monitor.activeOverlayEvent,
                    calendarService: calendarService
                )
            }
        }
    }

    private func update(seconds: Int, event: MeetingEvent?, calendarService: CalendarService?) {
        if let event, seconds > 0 {
            displayText = "\(truncate(event.title, to: 18)) starts in \(seconds)s"
            iconName = "timer"
        } else if seconds == 0, event != nil {
            displayText = "GO!"
            iconName = "timer"
        } else if let next = calendarService?.events.first(where: { $0.timeUntilStart > 0 }) {
            displayText = "\(truncate(next.title, to: 18)) in \(next.formattedTimeUntil)"
            iconName = "calendar.badge.clock"
        } else {
            displayText = "Countdown"
            iconName = "calendar.badge.clock"
        }
    }

    private func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length { return string }
        return String(string.prefix(length - 1)) + "…"
    }
}

// MARK: - Bridge view that forces MenuBarExtra label to re-render

struct StatusBarLabelBridge: View {
    @ObservedObject var statusBarManager: StatusBarManager

    var body: some View {
        // Use HStack instead of Label — Label in menu bar context often only renders the icon
        HStack(spacing: 4) {
            Image(systemName: statusBarManager.iconName)
            Text(statusBarManager.displayText)
        }
        // Force SwiftUI to treat each state as a new view
        .id("\(statusBarManager.iconName)-\(statusBarManager.displayText)")
    }
}

// MARK: - Overlay Coordinator

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
