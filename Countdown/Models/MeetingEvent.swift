import EventKit
import Foundation

struct MeetingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendar: String
    let calendarColor: String
    let videoLink: URL?
    let isAllDay: Bool

    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    var secondsUntilStart: Int {
        Int(ceil(timeUntilStart))
    }

    var minutesUntilStart: Int {
        Int(ceil(timeUntilStart / 60))
    }

    var isHappeningSoon: Bool {
        timeUntilStart > 0 && timeUntilStart <= 600
    }

    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var formattedTimeUntil: String {
        let total = minutesUntilStart
        if total <= 0 {
            return "Now"
        } else if total == 1 {
            return "1 min"
        } else if total < 60 {
            return "\(total) min"
        } else {
            let hours = total / 60
            let minutes = total % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    static func == (lhs: MeetingEvent, rhs: MeetingEvent) -> Bool {
        lhs.id == rhs.id
    }

    init(from ekEvent: EKEvent, videoLink: URL?) {
        let baseID = ekEvent.eventIdentifier ?? UUID().uuidString
        let dateStamp = ISO8601DateFormatter().string(from: ekEvent.startDate)
        self.id = "\(baseID)_\(dateStamp)"
        self.title = ekEvent.title ?? "Untitled Meeting"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.calendar = ekEvent.calendar.title
        self.calendarColor = ""
        self.videoLink = videoLink
        self.isAllDay = ekEvent.isAllDay
    }

    init(id: String, title: String, startDate: Date, endDate: Date,
         calendar: String, calendarColor: String = "",
         videoLink: URL? = nil, isAllDay: Bool = false) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendar = calendar
        self.calendarColor = calendarColor
        self.videoLink = videoLink
        self.isAllDay = isAllDay
    }
}
