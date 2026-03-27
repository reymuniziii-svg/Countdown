import Combine
import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController.shared

    var body: some Scene {
        Settings {
            SettingsView(
                calendarService: appController.calendarService,
                audioManager: appController.audioManager,
                meetingMonitor: appController.meetingMonitor
            )
        }
    }
}

// MARK: - StatusBarManager

@MainActor
final class StatusBarManager: ObservableObject {
    @Published var displayText: String = "Countdown"
    @Published var isAlertHighlighted = false

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var flashTimer: Timer?

    func configure(monitor: MeetingMonitor, calendarService: CalendarService) {
        updateTimer?.invalidate()
        updateTimer = nil
        flashTimer?.invalidate()
        flashTimer = nil
        isAlertHighlighted = false
        cancellables.removeAll()

        monitor.$countdownSeconds
            .combineLatest(monitor.$activeOverlayEvent)
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds, event in
                self?.update(seconds: seconds, event: event, calendarService: calendarService)
            }
            .store(in: &cancellables)

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

        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self, weak monitor] _ in
            Task { @MainActor in
                guard let monitor else { return }
                self?.update(
                    seconds: monitor.countdownSeconds,
                    event: monitor.activeOverlayEvent,
                    calendarService: calendarService
                )
            }
        }

        update(
            seconds: monitor.countdownSeconds,
            event: monitor.activeOverlayEvent,
            calendarService: calendarService
        )
    }

    private func update(seconds: Int, event: MeetingEvent?, calendarService: CalendarService?) {
        if let event, seconds > 0 {
            displayText = "\(truncate(event.title, to: 10)) in \(formatCountdown(seconds))"
            updateAlertState(seconds: seconds)
        } else if seconds == 0, event != nil {
            displayText = "GO!"
            updateAlertState(seconds: 0)
        } else if let next = calendarService?.events.first(where: { $0.timeUntilStart > 0 }) {
            displayText = "\(truncate(next.title, to: 10)) in \(formatUpcoming(next.timeUntilStart))"
            stopFlashing()
        } else {
            displayText = "Countdown"
            stopFlashing()
        }
    }

    private func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length { return string }
        return String(string.prefix(length - 1)) + "…"
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let boundedSeconds = max(0, seconds)
        let minutes = boundedSeconds / 60
        let remainingSeconds = boundedSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatUpcoming(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.up)))
        if totalSeconds < 60 {
            return formatCountdown(totalSeconds)
        }

        let totalMinutes = Int(ceil(Double(totalSeconds) / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h\(minutes)m"
    }

    private func updateAlertState(seconds: Int) {
        let flashEnabled = CountdownPreferences.bool(
            forKey: CountdownPreferences.menuBarFlashEnabled,
            default: true
        )

        guard flashEnabled, seconds <= 10 else {
            stopFlashing()
            return
        }

        if flashTimer != nil {
            return
        }

        isAlertHighlighted = true
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isAlertHighlighted.toggle()
            }
        }
    }

    private func stopFlashing() {
        flashTimer?.invalidate()
        flashTimer = nil
        isAlertHighlighted = false
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
