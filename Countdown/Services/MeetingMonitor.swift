import AppKit
import Combine
import Foundation

@MainActor
final class MeetingMonitor: ObservableObject {
    @Published var activeOverlayEvent: MeetingEvent?
    @Published var shouldShowOverlay = false
    @Published var countdownSeconds: Int = 0

    private let calendarService: CalendarService
    private let audioManager: AudioManager
    private var checkTimer: Timer?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var shownEventIDs: Set<String> = []
    private var snoozedEvents: [String: Date] = [:]
    private var lastCleanupDate = Date()

    var isEnabled: Bool {
        get { CountdownPreferences.bool(forKey: CountdownPreferences.countdownEnabled, default: true) }
        set {
            CountdownPreferences.set(newValue, forKey: CountdownPreferences.countdownEnabled)
            objectWillChange.send()
        }
    }

    var overlayEnabled: Bool {
        get { CountdownPreferences.bool(forKey: CountdownPreferences.overlayEnabled, default: true) }
        set {
            CountdownPreferences.set(newValue, forKey: CountdownPreferences.overlayEnabled)
            objectWillChange.send()
        }
    }

    /// Trigger lead time = active clip duration (capped at 30s), or 10s if no clip
    var triggerLeadTime: TimeInterval {
        audioManager.activeTrack?.countdownDuration ?? 10
    }

    init(calendarService: CalendarService, audioManager: AudioManager) {
        self.calendarService = calendarService
        self.audioManager = audioManager

        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.handleCalendarEventsUpdated(events)
            }
            .store(in: &cancellables)
    }

    func start() {
        checkTimer?.invalidate()
        // A 1s cadence keeps countdown/audio alignment tight without relying on coarse polling.
        checkTimer = Timer.scheduledOnMainRunLoop(interval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingMeetings()
            }
        }
        checkUpcomingMeetings()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        audioManager.stop()
        shouldShowOverlay = false
        activeOverlayEvent = nil
        countdownSeconds = 0
    }

    func snooze(minutes: Int = 1) {
        guard let event = activeOverlayEvent else { return }
        snoozedEvents[event.id] = Date().addingTimeInterval(TimeInterval(minutes * 60))
        shownEventIDs.remove(event.id)
        dismiss()
    }

    func joinMeeting() {
        guard let event = activeOverlayEvent, let url = event.videoLink else { return }
        NSWorkspace.shared.open(url)
        dismiss()
    }

    // MARK: - Meeting Check

    private func handleCalendarEventsUpdated(_ events: [MeetingEvent]) {
        if let activeOverlayEvent,
           !events.contains(where: { $0.id == activeOverlayEvent.id }) {
            dismiss()
        }

        checkUpcomingMeetings()
    }

    private func checkUpcomingMeetings() {
        guard isEnabled else { return }

        let now = Date()

        // Daily cleanup
        if !Calendar.current.isDate(now, inSameDayAs: lastCleanupDate) {
            shownEventIDs.removeAll()
            snoozedEvents.removeAll()
            lastCleanupDate = now
        }

        // Clean expired snoozes
        snoozedEvents = snoozedEvents.filter { $0.value > now }

        let leadTime = triggerLeadTime

        for event in calendarService.events {
            let timeUntil = event.startDate.timeIntervalSince(now)

            guard !shownEventIDs.contains(event.id) else { continue }

            if let snoozeUntil = snoozedEvents[event.id], now < snoozeUntil {
                continue
            }

            // Trigger when within lead time window
            if timeUntil > 0 && timeUntil <= leadTime {
                triggerCountdown(for: event, secondsRemaining: Int(ceil(timeUntil)))
                return
            }

            // Catch events that just started (within 60s)
            if timeUntil <= 0 && timeUntil > -60 {
                triggerCountdown(for: event, secondsRemaining: 0)
                return
            }
        }
    }

    private func triggerCountdown(for event: MeetingEvent, secondsRemaining: Int) {
        shownEventIDs.insert(event.id)
        activeOverlayEvent = event
        countdownSeconds = secondsRemaining

        if audioManager.countdownSoundEnabled, secondsRemaining > 0 {
            audioManager.play(countdownSecondsRemaining: secondsRemaining)
        }

        // Only show overlay if enabled
        shouldShowOverlay = overlayEnabled

        // Start countdown timer
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledOnMainRunLoop(interval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.countdownSeconds > 0 {
                    self.countdownSeconds -= 1
                }
                // Don't auto-dismiss — let the user dismiss or join
            }
        }
    }
}
