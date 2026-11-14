import Foundation
import Testing
@testable import Livewall

@Suite struct LocalizationTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let spanishFolder = root.appending(path: "Localization/es.lproj")

    private func spanish() throws -> [String: String] {
        let data = try Data(contentsOf: Self.spanishFolder.appending(path: "Localizable.strings"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }

    /// The specifiers a value uses, ignoring positional "1$" markers, sorted so reordering is allowed.
    private func specifiers(_ text: String) -> [String] {
        text.matches(of: #/%(?:\d+\$)?(@|lld)/#).map { String($0.output.1) }.sorted()
    }

    @Test func everyTranslationKeepsItsPlaceholders() throws {
        for (key, value) in try spanish() {
            #expect(specifiers(key) == specifiers(value), "\(key)")
        }
    }

    /// Fixed UI texts in the source must have a Spanish entry, or they would show in English on a Spanish Mac.
    @Test func everyFixedUITextIsTranslated() throws {
        let translations = try spanish()
        let ignored: Set = ["Livewall", "https://example.com", "float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse)"]
        let pattern = #/(?:Text|Button|Label|Toggle|Section|Picker|TextField|SecureField|Link|Tab|LabeledContent|ContentUnavailableView|\.alert|\.help|InspectorHeader\(title:|gallery|String\(localized:)\(?\s*"([^"\\]+)"/#
        let sources = FileManager.default.enumerator(at: Self.root.appending(path: "Sources"), includingPropertiesForKeys: nil)!
        var missing: [String] = []
        for case let file as URL in sources where file.pathExtension == "swift" {
            for match in try String(contentsOf: file, encoding: .utf8).matches(of: pattern) {
                let key = String(match.output.1)
                if !ignored.contains(key), translations[key] == nil { missing.append("\(file.lastPathComponent): \(key)") }
            }
        }
        #expect(missing.isEmpty, "\(missing)")
    }

    /// Interpolated texts: the key Swift builds at runtime must match the one in the file.
    @Test func interpolatedTextsResolve() throws {
        let bundle = try #require(Bundle(url: Self.spanishFolder))
        func es(_ value: String.LocalizationValue) -> String { String(localized: value, bundle: bundle) }
        let name = "Aurora"
        let number = 3
        #expect(es("Update to \(name) and restart") == "Actualizar a Aurora y reiniciar")
        #expect(es("Page \(number) of \(name)") == "Página 3 de Aurora")
        #expect(es("\(number) wallpapers on this page") == "3 fondos en esta página")
        #expect(es("\(number) fps") == "3 fps")
        #expect(es("Steam responded with HTTP error \(number).") == "Steam respondió con el error HTTP 3.")
        #expect(es("\(name), \(name), active") == "Aurora, Aurora, activo")
    }
}
