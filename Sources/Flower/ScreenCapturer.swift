import CoreImage
import CoreMedia
import os
@preconcurrency import ScreenCaptureKit
import FlowerCore

enum CaptureError: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display available to capture."
        }
    }
}

/// Streams a display with ScreenCaptureKit and keeps the latest frame as JPEG in a FrameStore.
@MainActor
final class ScreenCapturer: NSObject {
    private let sink: FrameSink
    private var stream: SCStream?
    var onStop: ((String) -> Void)?

    init(frames: FrameStore) {
        sink = FrameSink(frames: frames)
    }

    func setQuality(_ percent: Int) {
        sink.quality.withLock { $0 = Double(percent) / 100 }
    }

    /// Starts (or restarts) capture. Restarting is how display / interval / cursor changes are applied.
    func start(displayID: CGDirectDisplayID, intervalMs: Int, showCursor: Bool) async throws {
        await stop()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID })
            ?? content.displays.first(where: { $0.displayID == CGMainDisplayID() })
            ?? content.displays.first
        else { throw CaptureError.noDisplay }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        config.minimumFrameInterval = CMTime(value: CMTimeValue(intervalMs), timescale: 1000)
        config.showsCursor = showCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: config, delegate: sink)
        try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: sink.queue)
        sink.onStop = { [weak self] message in
            Task { @MainActor in
                self?.stream = nil
                self?.onStop?(message)
            }
        }
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }
}

/// Receives frames on a background queue; kept separate from the main-actor capturer.
private final class FrameSink: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let frames: FrameStore
    let quality = OSAllocatedUnfairLock(initialState: 0.75)
    let queue = DispatchQueue(label: "Flower.capture", qos: .userInitiated)
    /// Set before capture starts, read only from SCStream callbacks.
    var onStop: (@Sendable (String) -> Void)?
    private let context = CIContext()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init(frames: FrameStore) {
        self.frames = frames
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer
        else { return }

        let q = quality.withLock { $0 }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let options = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): q]
        if let jpeg = context.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) {
            frames.update(jpeg)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop?(error.localizedDescription)
    }
}
