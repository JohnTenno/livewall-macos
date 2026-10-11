// swift-tools-version: 6.2
import Foundation
import PackageDescription

// With only the Command Line Tools installed (no Xcode), SwiftPM sometimes fails to locate the Swift Testing macro plugin.
let testingPlugins = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: testingPlugins)
    ? [.unsafeFlags(["-plugin-path", testingPlugins]), .swiftLanguageMode(.v5)]
    : [.swiftLanguageMode(.v5)]

let package = Package(
    name: "Livewall",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Livewall", path: "Sources/Livewall", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "LivewallTests", dependencies: ["Livewall"], path: "Tests/LivewallTests",
                    swiftSettings: testSettings),
    ]
)
