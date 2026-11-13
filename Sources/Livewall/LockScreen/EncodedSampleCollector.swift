import CoreMedia
import Foundation

/// Thread-safe sink for VideoToolbox's output callbacks, which arrive on the encoder's own queue.
final class EncodedSampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var collected: [CMSampleBuffer] = []
    private var firstError: Error?

    func receive(status: OSStatus, sample: CMSampleBuffer?) {
        lock.lock()
        defer { lock.unlock() }
        guard status == noErr else {
            if firstError == nil {
                firstError = LockScreenError.encodingFailed("VideoToolbox \(status)")
            }
            return
        }
        if let sample {
            collected.append(sample)
        }
    }

    var samples: [CMSampleBuffer] {
        lock.lock()
        defer { lock.unlock() }
        return collected
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return firstError
    }
}
