import Foundation

/// The Steam login QR code DepotDownloader prints as text ("██" = dark module, "  " = light), as a square grid.
struct SteamQRCode: Equatable {
    static let header = "Use the Steam Mobile App to sign in with this QR code:"

    let modules: [[Bool]]

    /// The newest complete QR code in the output, or nil while it is still being printed.
    /// Steam refreshes the challenge every so often, and DepotDownloader then prints a new code below the old one.
    static func latest(in output: String) -> SteamQRCode? {
        guard let range = output.range(of: header, options: .backwards) else { return nil }
        let rows = output[range.upperBound...]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .drop { $0.isEmpty }
            .prefix { !$0.isEmpty && $0.allSatisfy { $0 == "█" || $0 == " " } }
            .map { line in
                let characters = Array(line)
                return stride(from: 0, to: characters.count - 1, by: 2).map { characters[$0] == "█" }
            }
        guard let width = rows.first?.count, width > 0, rows.count >= width else { return nil }
        return SteamQRCode(modules: Array(rows.prefix(width)))
    }
}
