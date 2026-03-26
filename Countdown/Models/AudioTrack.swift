import Foundation

struct AudioTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let fileName: String
    let duration: TimeInterval

    /// User-chosen segment start (seconds into the clip)
    var segmentStart: TimeInterval

    /// User-chosen segment end (seconds into the clip)
    var segmentEnd: TimeInterval

    /// The playable segment length (capped at 30s)
    var segmentDuration: TimeInterval {
        min(segmentEnd - segmentStart, 30)
    }

    /// Effective countdown duration = segment length
    var countdownDuration: TimeInterval {
        segmentDuration
    }

    /// Playback starts at segmentStart
    var playbackStartOffset: TimeInterval {
        segmentStart
    }

    /// Playback ends at segmentEnd (for stopping)
    var playbackEndOffset: TimeInterval {
        segmentEnd
    }

    init(id: UUID = UUID(), name: String, fileName: String, duration: TimeInterval,
         segmentStart: TimeInterval? = nil, segmentEnd: TimeInterval? = nil) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
        // Default: last 30s of clip (or full clip if ≤30s)
        self.segmentStart = segmentStart ?? max(0, duration - 30)
        self.segmentEnd = segmentEnd ?? duration
    }
}
