import EventKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        TabView {
            GeneralSettingsView(calendarService: calendarService)
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
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared

    var body: some View {
        Form {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { launchAtLoginManager.setEnabled($0) }
                )
            )
            .disabled(!launchAtLoginManager.canManageLaunchAtLogin)

            Text("Install Countdown.app before enabling this so macOS can relaunch it reliably.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Section("Diagnostics") {
                LabeledContent("App Bundle", value: bundleStatusLabel)
                LabeledContent(
                    "Calendar Access",
                    value: calendarService.hasCalendarAccess ? "Granted" : "Needs access"
                )
                LabeledContent(
                    "Launch at Login",
                    value: launchAtLoginManager.isEnabled ? "Enabled" : "Disabled"
                )
                Text(Bundle.main.bundleURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let lastError = launchAtLoginManager.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
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

            List {
                ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { cal in
                    Toggle(cal.title, isOn: Binding(
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
                    ))
                }
            }
        }
        .padding()
    }
}
