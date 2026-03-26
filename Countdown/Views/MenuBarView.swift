import SwiftUI

struct MenuBarView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var meetingMonitor: MeetingMonitor
    @ObservedObject var audioManager: AudioManager
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = { NSApp.terminate(nil) }
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared

    private var upcomingEvents: [MeetingEvent] {
        calendarService.events.filter { $0.timeUntilStart > -300 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with toggle
            headerSection

            Divider().padding(.vertical, 6)

            if !calendarService.hasCalendarAccess {
                calendarAccessSection
            } else if upcomingEvents.isEmpty {
                noEventsSection
            } else {
                eventListSection
            }

            Divider().padding(.vertical, 6)

            // Soundtrack section
            soundtrackSection

            Divider().padding(.vertical, 6)

            diagnosticsSection

            Divider().padding(.vertical, 6)

            // Footer
            footerSection
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("COUNTDOWN")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { meetingMonitor.isEnabled },
                    set: { meetingMonitor.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            HStack(spacing: 4) {
                Image(systemName: meetingMonitor.overlayEnabled ? "rectangle.inset.filled" : "rectangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Full-screen overlay")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { meetingMonitor.overlayEnabled },
                    set: { meetingMonitor.overlayEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
    }

    // MARK: - Calendar Access

    private var calendarAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Calendar Access Required", systemImage: "calendar.badge.exclamationmark")
                .font(.headline)
            Text("Grant access in System Settings → Privacy & Security → Calendars")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Request Access") {
                Task { await calendarService.requestAccess() }
            }
            .controlSize(.small)
        }
    }

    // MARK: - No Events

    private var noEventsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No upcoming meetings", systemImage: "checkmark.circle")
                .font(.system(size: 13, weight: .medium))
            Text("You're free for the rest of the day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Event List

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(upcomingEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                eventRow(event, isNext: index == 0)
                if index < min(2, upcomingEvents.count - 1) {
                    Divider().padding(.vertical, 2)
                }
            }
        }
    }

    private func eventRow(_ event: MeetingEvent, isNext: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isNext {
                        Text("Next:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(event.title)
                        .font(.system(size: 13, weight: isNext ? .semibold : .regular))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(event.formattedStartTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if event.isInProgress {
                        Text("· In progress")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    } else {
                        Text("· in \(event.formattedTimeUntil)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let url = event.videoLink {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .help("Join \(VideoLinkDetector.serviceName(for: url))")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Soundtrack

    private var soundtrackSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Soundtrack", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(Array(audioManager.tracks.enumerated()), id: \.element.id) { index, track in
                trackRow(track, index: index)
            }

            if audioManager.tracks.count < 3 {
                Button {
                    audioManager.importTrack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text(audioManager.tracks.isEmpty ? "Add soundtrack" : "Add another")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private func trackRow(_ track: AudioTrack, index: Int) -> some View {
        HStack(spacing: 6) {
            // Radio button
            Image(systemName: index == audioManager.selectedTrackIndex ? "circle.inset.filled" : "circle")
                .font(.system(size: 10))
                .foregroundColor(index == audioManager.selectedTrackIndex ? .accentColor : .secondary)
                .onTapGesture {
                    audioManager.selectTrack(at: index)
                }

            Text(track.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            Text(formatDuration(track.segmentDuration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // Preview button
            Button {
                if audioManager.isPlaying {
                    audioManager.stop()
                } else {
                    audioManager.previewTrack(at: index)
                }
            } label: {
                Image(systemName: audioManager.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Preview")

            // Delete button
            Button {
                audioManager.removeTrack(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 1)
    }

    // MARK: - Footer

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Diagnostics", systemImage: "checklist")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            diagnosticRow(
                label: "App",
                value: appBundleStatus,
                color: appBundleStatusColor
            )
            diagnosticRow(
                label: "Calendar",
                value: calendarService.hasCalendarAccess ? "Granted" : "Needs access",
                color: calendarService.hasCalendarAccess ? .green : .orange
            )
            diagnosticRow(
                label: "Login",
                value: launchAtLoginManager.isEnabled ? "Enabled" : "Off",
                color: launchAtLoginManager.isEnabled ? .green : .secondary
            )
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                onOpenSettings()
            } label: {
                Text("Preferences...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                onQuit()
            } label: {
                Text("Quit Countdown")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return "\(s)s"
    }

    private func diagnosticRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private var appBundleStatus: String {
        let bundlePath = Bundle.main.bundleURL.path
        if bundlePath.hasPrefix("/Applications/") {
            return "Installed"
        }
        if Bundle.main.bundleURL.pathExtension == "app" {
            return "Bundle"
        }
        return "Dev Run"
    }

    private var appBundleStatusColor: Color {
        switch appBundleStatus {
        case "Installed":
            return .green
        case "Bundle":
            return .orange
        default:
            return .secondary
        }
    }
}
