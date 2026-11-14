import Foundation

/// Collects a child process's output from the pipe's background queue.
final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }

    /// Adds a chunk and returns everything collected so far.
    func append(_ chunk: Data) -> String {
        lock.withLock {
            data.append(chunk)
            return String(decoding: data, as: UTF8.self)
        }
    }
}
