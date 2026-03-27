import EventKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var meetingMonitor: MeetingMonitor

    var body: some View {
        TabView {
            GeneralSettingsView(
                calendarService: calendarService,
                audioManager: audioManager,
                meetingMonitor: meetingMonitor
            )
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AudioSettingsView(audioManager: audioManager)
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }

            CalendarSettingsView(calendarService: calendarService)
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }
        }
        .frame(width: 450, height: 400)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var meetingMonitor: MeetingMonitor
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @AppStorage(CountdownPreferences.menuBarFlashEnabled) private var menuBarFlashEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsCard("Behavior") {
                    settingsToggle(
                        title: "Launch at login",
                        detail: "Start Countdown automatically after you sign in to macOS.",
                        isOn: Binding(
                            get: { launchAtLoginManager.isEnabled },
                            set: { launchAtLoginManager.setEnabled($0) }
                        ),
                        isDisabled: !launchAtLoginManager.canManageLaunchAtLogin
                    )

                    settingsToggle(
                        title: "Full-screen countdown",
                        detail: "Show the full-screen dramatic overlay before meetings.",
                        isOn: Binding(
                            get: { meetingMonitor.overlayEnabled },
                            set: { meetingMonitor.overlayEnabled = $0 }
                        )
                    )

                    settingsToggle(
                        title: "Flash red in menu bar",
                        detail: "Make the menu bar countdown flash red during the last 10 seconds.",
                        isOn: $menuBarFlashEnabled
                    )

                    settingsToggle(
                        title: "Sound effect",
                        detail: "Play your selected soundtrack before meetings.",
                        isOn: Binding(
                            get: { audioManager.countdownSoundEnabled },
                            set: { audioManager.countdownSoundEnabled = $0 }
                        )
                    )
                }

                settingsCard("Diagnostics") {
                    diagnosticsRow("App Bundle", value: bundleStatusLabel)
                    diagnosticsRow(
                        "Calendar Access",
                        value: calendarService.hasCalendarAccess ? "Granted" : "Needs access"
                    )
                    diagnosticsRow(
                        "Launch at Login",
                        value: launchAtLoginManager.isEnabled ? "Enabled" : "Disabled"
                    )
                    diagnosticsRow(
                        "Sound Effect",
                        value: audioManager.countdownSoundEnabled ? "Enabled" : "Muted"
                    )
                    Text(Bundle.main.bundleURL.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }

                if let lastError = launchAtLoginManager.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 2)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func settingsToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isDisabled)
        }
    }

    private func diagnosticsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.system(size: 13))
    }

    private var bundleStatusLabel: String {
        let bundlePath = Bundle.main.bundleURL.path
        if bundlePath.hasPrefix("/Applications/") {
            return "Installed"
        }
        if Bundle.main.bundleURL.pathExtension == "app" {
            return "Bundle"
        }
        return "Development"
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Manage Soundtracks")
                    .font(.headline)

                Text("Upload up to 3 audio clips. Drag the slider to choose which segment plays before meetings (max 30s). Audio fades in smoothly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(audioManager.tracks.enumerated()), id: \.element.id) { index, track in
                    AudioTrackCard(
                        track: track,
                        index: index,
                        isSelected: index == audioManager.selectedTrackIndex,
                        isPlaying: audioManager.isPlaying,
                        onPreview: {
                            if audioManager.isPlaying {
                                audioManager.stop()
                            } else {
                                audioManager.previewTrack(at: index)
                            }
                        },
                        onDelete: { audioManager.removeTrack(at: index) },
                        onSegmentChange: { start, end in
                            audioManager.updateSegment(at: index, start: start, end: end)
                        }
                    )
                }

                if audioManager.tracks.count < 3 {
                    Button("Add Audio Clip...") {
                        audioManager.importTrack()
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Audio Track Card with Segment Slider

struct AudioTrackCard: View {
    let track: AudioTrack
    let index: Int
    let isSelected: Bool
    let isPlaying: Bool
    let onPreview: () -> Void
    let onDelete: () -> Void
    let onSegmentChange: (TimeInterval, TimeInterval) -> Void

    @State private var segStart: Double = 0
    @State private var segEnd: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.system(size: 13, weight: .medium))

                    HStack(spacing: 8) {
                        Text("Full clip: \(formatTime(track.duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Playing: \(formatTime(segEnd - segStart))")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                Button(action: onPreview) {
                    Image(systemName: isPlaying ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderless)
                .help("Preview selected segment")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            // Segment slider
            VStack(spacing: 4) {
                SegmentRangeSlider(
                    start: $segStart,
                    end: $segEnd,
                    range: 0...track.duration,
                    maxSegment: 30,
                    onChange: { onSegmentChange(segStart, segEnd) }
                )

                // Time labels
                HStack {
                    Text(formatTime(segStart))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatTime(segEnd - segStart)) selected")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor)
                    Spacer()
                    Text(formatTime(segEnd))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            segStart = track.segmentStart
            segEnd = track.segmentEnd
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let min = s / 60
        let sec = s % 60
        if min > 0 {
            return String(format: "%d:%02d", min, sec)
        }
        return "\(sec)s"
    }
}

// MARK: - Custom Range Slider

struct SegmentRangeSlider: View {
    @Binding var start: Double
    @Binding var end: Double
    let range: ClosedRange<Double>
    let maxSegment: Double
    let onChange: () -> Void

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let rangeSpan = range.upperBound - range.lowerBound

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                // Selected range highlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(
                        width: max(0, CGFloat((end - start) / rangeSpan) * width),
                        height: trackHeight
                    )
                    .offset(x: CGFloat((start - range.lowerBound) / rangeSpan) * width + thumbSize / 2)

                // Start thumb
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: CGFloat((start - range.lowerBound) / rangeSpan) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let pct = max(0, min(1, value.location.x / width))
                                var newStart = range.lowerBound + pct * rangeSpan
                                newStart = max(range.lowerBound, min(newStart, end - 1))
                                // Enforce max segment
                                if end - newStart > maxSegment {
                                    newStart = end - maxSegment
                                }
                                start = newStart
                            }
                            .onEnded { _ in onChange() }
                    )

                // End thumb
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: CGFloat((end - range.lowerBound) / rangeSpan) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let pct = max(0, min(1, value.location.x / width))
                                var newEnd = range.lowerBound + pct * rangeSpan
                                newEnd = max(start + 1, min(newEnd, range.upperBound))
                                // Enforce max segment
                                if newEnd - start > maxSegment {
                                    newEnd = start + maxSegment
                                }
                                end = newEnd
                            }
                            .onEnded { _ in onChange() }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}

// MARK: - Calendar Settings

struct CalendarSettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @State private var enabledIDs: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") ?? []
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select which calendars to monitor")
                .font(.headline)

            Text("Leave all unchecked to monitor all calendars.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !calendarService.hasCalendarAccess {
                accessRequiredState
            } else if calendarService.availableCalendars.isEmpty {
                emptyCalendarsState
            } else {
                List {
                    ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { cal in
                        Toggle(isOn: Binding(
                            get: { enabledIDs.contains(cal.calendarIdentifier) },
                            set: { isOn in
                                if isOn {
                                    enabledIDs.insert(cal.calendarIdentifier)
                                } else {
                                    enabledIDs.remove(cal.calendarIdentifier)
                                }
                                UserDefaults.standard.set(Array(enabledIDs), forKey: "enabledCalendarIDs")
                                calendarService.fetchEvents()
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cal.title)
                                Text(cal.source.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            calendarService.refreshState()
        }
    }

    private var accessRequiredState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Calendar access is required", systemImage: "calendar.badge.exclamationmark")
                .font(.headline)

            Text("Allow access and reopen this tab to load your available calendars.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Request Access") {
                Task {
                    await calendarService.requestAccess()
                    calendarService.refreshState()
                }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyCalendarsState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No calendars found yet", systemImage: "tray")
                .font(.headline)

            Text("Countdown only sees calendars that are already available in Apple Calendar on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Refresh Calendars") {
                calendarService.refreshState()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
