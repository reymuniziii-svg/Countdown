// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Countdown",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Countdown",
            path: "Countdown",
            exclude: ["Info.plist", "Countdown.entitlements"]
        )
    ]
)
