import CoreMedia
import Foundation

/// Thread-safe sink for VideoToolbox's output callbacks, which arrive on the encoder's own queue.
final class EncodedSampleCollector {
    private let lock = NSLock()
    private var collected: [CMSampleBuffer] = []
    private var firstError: Error?

    func receive(status: OSStatus, sample: CMSampleBuffer?) {
        lock.lock()
        defer { lock.unlock() }
        if let sample, status == noErr {
            collected.append(sample)
        } else if firstError == nil {
            firstError = LockScreenError.encodingFailed("VideoToolbox \(status)")
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
