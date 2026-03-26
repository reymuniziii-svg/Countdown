import Foundation

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private let launchAgentLabel = "com.countdown.app.launcher"

    private init() {
        refreshStatus()
    }

    var canManageLaunchAtLogin: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func refreshStatus() {
        isEnabled = fileManager.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        guard canManageLaunchAtLogin else {
            lastError = "Install Countdown.app before enabling launch at login."
            refreshStatus()
            return
        }

        do {
            if enabled {
                try enable()
            } else {
                try disable()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        refreshStatus()
    }

    private var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentLabel).plist")
    }

    private func enable() throws {
        let launchAgentsDirectory = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": ["/usr/bin/open", Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: launchAgentURL, options: .atomic)

        try runLaunchctl(arguments: ["bootout", launchctlDomain, launchAgentURL.path], allowFailure: true)
        try runLaunchctl(arguments: ["bootstrap", launchctlDomain, launchAgentURL.path])
    }

    private func disable() throws {
        try runLaunchctl(arguments: ["bootout", launchctlDomain, launchAgentURL.path], allowFailure: true)

        if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }

    private var launchctlDomain: String {
        "gui/\(getuid())"
    }

    private func runLaunchctl(arguments: [String], allowFailure: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 || allowFailure else {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "LaunchAtLoginManager",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage?.isEmpty == false ? errorMessage! : "launchctl failed."
                ]
            )
        }
    }
}
