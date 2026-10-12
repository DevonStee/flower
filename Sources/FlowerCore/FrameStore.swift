import Foundation
import os

/// Holds the most recent JPEG frame. Written by the capture queue, read by the HTTP queue.
/// Replaces the original app's "write frame.jpg to disk + reader/writer lock" approach.
public final class FrameStore: Sendable {
    private let state = OSAllocatedUnfairLock<Data?>(initialState: nil)

    public init() {}

    public var latest: Data? {
        state.withLock { $0 }
    }

    public func update(_ frame: Data?) {
        state.withLock { $0 = frame }
    }
}
