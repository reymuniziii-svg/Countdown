import Foundation

struct AudioTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let fileName: String
    let duration: TimeInterval

    /// Effective countdown duration: clip length capped at 30 seconds
    var countdownDuration: TimeInterval {
        min(duration, 30)
    }

    /// If clip is longer than 30s, we seek to this offset to play the last 30s
    var playbackStartOffset: TimeInterval {
        duration > 30 ? duration - 30 : 0
    }

    init(id: UUID = UUID(), name: String, fileName: String, duration: TimeInterval) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
    }
}
