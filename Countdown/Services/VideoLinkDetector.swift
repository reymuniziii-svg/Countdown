import EventKit
import Foundation

enum VideoLinkDetector {
    private static let patterns: [(name: String, regex: String)] = [
        ("Zoom", #"https?://[\w.-]*zoom\.us/[jw]/\S+"#),
        ("Google Meet", #"https?://meet\.google\.com/\S+"#),
        ("Microsoft Teams", #"https?://teams\.microsoft\.com/l/meetup-join/\S+"#),
        ("Webex", #"https?://[\w.-]*webex\.com/\S+"#),
        ("Slack Huddle", #"https?://[\w.-]*slack\.com/huddle/\S+"#),
    ]

    static func detectLink(in event: EKEvent) -> URL? {
        // Check event URL first
        if let url = event.url, isVideoLink(url) {
            return url
        }

        // Search notes and location
        let searchText = [event.notes, event.location]
            .compactMap { $0 }
            .joined(separator: " ")

        return findVideoURL(in: searchText)
    }

    static func serviceName(for url: URL) -> String {
        let urlString = url.absoluteString.lowercased()
        for (name, _) in patterns {
            switch name {
            case "Zoom" where urlString.contains("zoom.us"):
                return name
            case "Google Meet" where urlString.contains("meet.google.com"):
                return name
            case "Microsoft Teams" where urlString.contains("teams.microsoft.com"):
                return name
            case "Webex" where urlString.contains("webex.com"):
                return name
            case "Slack Huddle" where urlString.contains("slack.com"):
                return name
            default:
                continue
            }
        }
        return "Meeting"
    }

    private static func isVideoLink(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        return patterns.contains { _, regex in
            urlString.range(of: regex, options: .regularExpression) != nil
        }
    }

    private static func findVideoURL(in text: String) -> URL? {
        for (_, regex) in patterns {
            guard let range = text.range(of: regex, options: .regularExpression) else { continue }
            var urlString = String(text[range])
            // Clean trailing punctuation
            while let last = urlString.last, [".", ",", ")", ">", ";"].contains(String(last)) {
                urlString.removeLast()
            }
            if let url = URL(string: urlString) {
                return url
            }
        }
        return nil
    }
}
