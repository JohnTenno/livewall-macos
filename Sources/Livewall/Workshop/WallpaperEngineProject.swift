import Foundation

/// The `project.json` that every Wallpaper Engine item ships with.
struct WallpaperEngineProject: Decodable {
    static let fileName = "project.json"

    let title: String?
    let type: String?
    let file: String?
    let general: General?

    struct General: Decodable {
        /// User-tweakable options; each has at least a `value`.
        let properties: [String: Property]?
    }

    struct Property: Decodable {
        let value: JSONValue?
    }

    static func load(from folder: URL) throws -> WallpaperEngineProject {
        let data = try Data(contentsOf: folder.appending(path: fileName))
        return try JSONDecoder().decode(WallpaperEngineProject.self, from: data)
    }

    /// The default property values in the shape `wallpaperPropertyListener.applyUserProperties` expects.
    func defaultPropertiesJSON() -> String {
        var payload: [String: Any] = [:]
        for (key, property) in general?.properties ?? [:] {
            if let value = property.value?.foundationValue {
                payload[key] = ["value": value]
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
