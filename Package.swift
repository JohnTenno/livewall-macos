// swift-tools-version: 6.2
import Foundation
import PackageDescription

// With only the Command Line Tools installed (no Xcode), SwiftPM sometimes fails to locate Swift Testing.
let testingPlugins = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testingFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

var testSwiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]
var testLinkerSettings: [LinkerSetting] = []

if FileManager.default.fileExists(atPath: testingPlugins) {
    testSwiftSettings.append(.unsafeFlags(["-plugin-path", testingPlugins]))
}
if FileManager.default.fileExists(atPath: testingFrameworks) {
    testSwiftSettings.append(.unsafeFlags([
        "-F", testingFrameworks,
        "-Xfrontend", "-disable-cross-import-overlays",
    ]))
    testLinkerSettings.append(.unsafeFlags([
        "-F", testingFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", testingFrameworks,
    ]))
}

let package = Package(
    name: "Livewall",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Livewall", path: "Sources/Livewall", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "LivewallTests", dependencies: ["Livewall"], path: "Tests/LivewallTests",
                    swiftSettings: testSwiftSettings,
                    linkerSettings: testLinkerSettings),
    ]
)
