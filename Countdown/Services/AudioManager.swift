import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioManager: ObservableObject {
    @Published var tracks: [AudioTrack] = []
    @Published var selectedTrackIndex: Int = 0
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    private static let maxTracks = 3
    private static let fadeInDuration: TimeInterval = 3.0
    private static let fadeInSteps = 30 // volume updates during fade

    private var audioDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Countdown/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var activeTrack: AudioTrack? {
        guard !tracks.isEmpty, selectedTrackIndex < tracks.count else { return nil }
        return tracks[selectedTrackIndex]
    }

    init() {
        loadTracks()
    }

    // MARK: - Track Management

    func importTrack() {
        guard tracks.count < Self.maxTracks else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .wav, .aiff, .audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select an audio clip (up to 30s will play before meetings)"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        Task {
            await importTrackFromURL(sourceURL)
        }
    }

    func importTrackFromURL(_ sourceURL: URL) async {
        guard tracks.count < Self.maxTracks else { return }

        let asset = AVURLAsset(url: sourceURL)
        let duration: TimeInterval
        do {
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
        } catch {
            print("Failed to read audio duration: \(error)")
            return
        }

        guard duration > 0 else { return }

        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
        let destURL = audioDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            print("Failed to copy audio file: \(error)")
            return
        }

        let name = sourceURL.deletingPathExtension().lastPathComponent
        let track = AudioTrack(name: name, fileName: fileName, duration: duration)
        tracks.append(track)

        if tracks.count == 1 {
            selectedTrackIndex = 0
        }

        saveTracks()
    }

    func removeTrack(at index: Int) {
        guard index < tracks.count else { return }

        let track = tracks[index]
        let fileURL = audioDirectory.appendingPathComponent(track.fileName)
        try? FileManager.default.removeItem(at: fileURL)

        tracks.remove(at: index)

        if selectedTrackIndex >= tracks.count {
            selectedTrackIndex = max(0, tracks.count - 1)
        }

        saveTracks()
    }

    func selectTrack(at index: Int) {
        guard index < tracks.count else { return }
        selectedTrackIndex = index
        UserDefaults.standard.set(index, forKey: "selectedTrackIndex")
    }

    // MARK: - Playback

    func play() {
        guard let track = activeTrack else { return }

        let fileURL = audioDirectory.appendingPathComponent(track.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.volume = 0
            player?.prepareToPlay()

            // If clip > 30s, seek to play just the last 30s
            if track.playbackStartOffset > 0 {
                player?.currentTime = track.playbackStartOffset
            }

            player?.play()
            isPlaying = true
            startFadeIn()
        } catch {
            print("Audio playback error: \(error)")
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
    }

    func previewTrack(at index: Int) {
        stop()

        guard index < tracks.count else { return }
        let track = tracks[index]
        let fileURL = audioDirectory.appendingPathComponent(track.fileName)

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.volume = 0
            player?.prepareToPlay()

            if track.playbackStartOffset > 0 {
                player?.currentTime = track.playbackStartOffset
            }

            player?.play()
            isPlaying = true
            startFadeIn()
        } catch {
            print("Preview playback error: \(error)")
        }
    }

    // MARK: - Fade In

    private func startFadeIn() {
        fadeTimer?.invalidate()

        let stepInterval = Self.fadeInDuration / Double(Self.fadeInSteps)
        let volumeStep = Float(1.0) / Float(Self.fadeInSteps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, let player = self.player else {
                    timer.invalidate()
                    return
                }

                currentStep += 1
                player.volume = min(1.0, volumeStep * Float(currentStep))

                if currentStep >= Self.fadeInSteps {
                    timer.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveTracks() {
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: "audioTracks")
        }
        UserDefaults.standard.set(selectedTrackIndex, forKey: "selectedTrackIndex")
    }

    private func loadTracks() {
        if let data = UserDefaults.standard.data(forKey: "audioTracks"),
           let saved = try? JSONDecoder().decode([AudioTrack].self, from: data) {
            tracks = saved
        }
        selectedTrackIndex = UserDefaults.standard.integer(forKey: "selectedTrackIndex")
        if selectedTrackIndex >= tracks.count {
            selectedTrackIndex = 0
        }
    }
}
