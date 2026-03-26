import EventKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        TabView {
            GeneralSettingsView()
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
        .frame(width: 420, height: 300)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if #available(macOS 13.0, *) {
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Launch at login error: \(error)")
                        }
                    }
                }
        }
        .padding()
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Soundtracks")
                .font(.headline)

            Text("Upload up to 3 audio clips. The countdown will match the clip length (max 30 seconds). Audio fades in smoothly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(audioManager.tracks.enumerated()), id: \.element.id) { index, track in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.system(size: 13, weight: .medium))

                        HStack(spacing: 8) {
                            Text("Duration: \(Int(track.duration))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if track.duration > 30 {
                                Text("(plays last 30s)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Text("Countdown: \(Int(track.countdownDuration))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        if audioManager.isPlaying {
                            audioManager.stop()
                        } else {
                            audioManager.previewTrack(at: index)
                        }
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "stop.circle" : "play.circle")
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        audioManager.removeTrack(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(index == audioManager.selectedTrackIndex ? Color.accentColor.opacity(0.1) : Color.clear)
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
