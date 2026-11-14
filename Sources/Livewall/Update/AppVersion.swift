import Foundation

/// A dotted numeric version ("0.2.0", tag "v0.2.0"); missing parts count as 0.
struct AppVersion: Comparable, CustomStringConvertible {
    let parts: [Int]

    init?(_ text: String) {
        let trimmed = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = trimmed.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    static var current: AppVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        let left = lhs.parts + Array(repeating: 0, count: count - lhs.parts.count)
        let right = rhs.parts + Array(repeating: 0, count: count - rhs.parts.count)
        return left.lexicographicallyPrecedes(right)
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }

    var description: String { parts.map(String.init).joined(separator: ".") }
}
