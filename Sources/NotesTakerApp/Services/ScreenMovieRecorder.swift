import AppKit
import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

enum ScreenMovieRecorderError: LocalizedError {
    case screenPermissionDenied
    case noDisplay
    case writerSetupFailed(String)
    case startFailed(String)
    case stopFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenPermissionDenied:
            "Screen Recording is not active for this exact app. In System Settings, remove NotesTaker with −, add /Applications/NotesTaker.app with +, then quit and reopen NotesTaker."
        case .noDisplay:
            "Could not find a display to capture."
        case .writerSetupFailed(let detail):
            "Could not prepare the movie file: \(detail)"
        case .startFailed(let detail):
            "The recording could not be started: \(detail)"
        case .stopFailed(let detail):
            "The recording could not be stopped cleanly: \(detail)"
        }
    }
}

@MainActor
final class ScreenMovieRecorder: NSObject {
    private let sampleQueue = DispatchQueue(label: "com.tahirawan.notestaker.capture")
    private let writerState = WriterState()
    private var stream: SCStream?
    private var outputURL: URL?

    var isRecording: Bool {
        stream != nil
    }

    func start(to url: URL) async throws {
        NSLog("[NotesTaker] Recording start requested → %@", url.path)

        let preflight = CGPreflightScreenCaptureAccess()
        NSLog(
            "[NotesTaker] Screen capture preflight=%@ bundle=%@",
            preflight ? "true" : "false",
            Bundle.main.bundleURL.path
        )

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            NSLog("[NotesTaker] ScreenCaptureKit shareable content failed: %@", String(describing: error))
            // Do not auto-open Settings here. During development and reinstall, TCC can keep
            // a stale NotesTaker row enabled while treating the new binary as a different app.
            // Calling CGRequestScreenCaptureAccess repeatedly causes the modal loop the user saw.
            if preflight {
                throw ScreenMovieRecorderError.startFailed(
                    "macOS still blocked capture even though Screen Recording looks enabled. Remove NotesTaker with −, add this exact app with +, then quit and reopen NotesTaker: \(Bundle.main.bundleURL.path)"
                )
            }
            throw ScreenMovieRecorderError.screenPermissionDenied
        }

        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw ScreenMovieRecorderError.noDisplay
        }

        let scale = max(Int(NSScreen.main?.backingScaleFactor ?? 2), 1)
        let width = max(display.width * scale, 2)
        let height = max(display.height * scale, 2)
        NSLog("[NotesTaker] Capturing display %u at %dx%d (scale %d)", display.displayID, width, height, scale)

        try? FileManager.default.removeItem(at: url)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            throw ScreenMovieRecorderError.writerSetupFailed(error.localizedDescription)
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 3, 2_000_000),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelAttributes
        )

        guard writer.canAdd(videoInput) else {
            throw ScreenMovieRecorderError.writerSetupFailed("Video input was rejected.")
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
        let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        micInput.expectsMediaDataInRealTime = true
        if writer.canAdd(micInput) {
            writer.add(micInput)
            audioInput = micInput
        }

        guard writer.startWriting() else {
            throw ScreenMovieRecorderError.writerSetupFailed(writer.error?.localizedDescription ?? "Unknown writer error")
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 5
        configuration.showsCursor = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        if #available(macOS 15.0, *) {
            configuration.captureMicrophone = audioInput != nil
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        if #available(macOS 15.0, *), audioInput != nil {
            do {
                try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: sampleQueue)
            } catch {
                NSLog("[NotesTaker] Microphone stream output unavailable: %@", String(describing: error))
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sampleQueue.async { [writerState] in
                writerState.reset(writer: writer, videoInput: videoInput, audioInput: audioInput, adaptor: adaptor)
                continuation.resume()
            }
        }

        self.stream = stream
        self.outputURL = url

        do {
            try await stream.startCapture()
            NSLog("[NotesTaker] ScreenCaptureKit stream started")
        } catch {
            NSLog("[NotesTaker] startCapture failed: %@", String(describing: error))
            await teardownAfterFailure()
            throw ScreenMovieRecorderError.startFailed(error.localizedDescription)
        }
    }

    func stop() async throws -> URL {
        guard let stream, let outputURL else {
            throw ScreenMovieRecorderError.stopFailed("No active recording.")
        }

        NSLog("[NotesTaker] Recording stop requested")
        do {
            try await stream.stopCapture()
        } catch {
            NSLog("[NotesTaker] stopCapture error: %@", String(describing: error))
        }
        self.stream = nil

        let finishError = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            sampleQueue.async { [writerState] in
                writerState.finish { error in
                    continuation.resume(returning: error)
                }
            }
        }

        self.outputURL = nil

        if let finishError {
            throw ScreenMovieRecorderError.stopFailed(finishError.localizedDescription)
        }

        NSLog("[NotesTaker] Recording saved → %@", outputURL.path)
        return outputURL
    }

    private func teardownAfterFailure() async {
        if let stream {
            try? await stream.stopCapture()
        }
        self.stream = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sampleQueue.async { [writerState] in
                writerState.cancel()
                continuation.resume()
            }
        }
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        self.outputURL = nil
    }

}

extension ScreenMovieRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("[NotesTaker] Stream stopped with error: %@", String(describing: error))
    }
}

extension ScreenMovieRecorder: SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else { return }

        switch type {
        case .screen:
            guard isCompleteFrame(sampleBuffer), let imageBuffer = sampleBuffer.imageBuffer else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writerState.appendVideo(pixelBuffer: imageBuffer, at: timestamp)
        case .microphone, .audio:
            writerState.appendAudio(sampleBuffer)
        @unknown default:
            break
        }
    }

    nonisolated private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let statusRaw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRaw)
        else {
            return true
        }
        return status == .complete
    }
}

/// Mutable AVAssetWriter state confined to the capture queue.
private final class WriterState: @unchecked Sendable {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false
    private var didLogFirstFrame = false

    func reset(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) {
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.adaptor = adaptor
        self.sessionStarted = false
        self.didLogFirstFrame = false
    }

    func appendVideo(pixelBuffer: CVPixelBuffer, at time: CMTime) {
        guard let writer, let videoInput, let adaptor else { return }
        if !sessionStarted {
            writer.startSession(atSourceTime: time)
            sessionStarted = true
        }
        guard videoInput.isReadyForMoreMediaData else { return }
        if adaptor.append(pixelBuffer, withPresentationTime: time), !didLogFirstFrame {
            didLogFirstFrame = true
            NSLog("[NotesTaker] First video frame written at %.3f", CMTimeGetSeconds(time))
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let writer, let audioInput else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startSession(atSourceTime: time)
            sessionStarted = true
        }
        guard audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }

    func finish(completion: @escaping @Sendable (Error?) -> Void) {
        guard let writer else {
            completion(ScreenMovieRecorderError.stopFailed("Writer missing."))
            return
        }
        let capturedWriter = writer
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        capturedWriter.finishWriting {
            let error: Error? = capturedWriter.status == .completed ? nil : capturedWriter.error
            completion(error)
        }
        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.adaptor = nil
        self.sessionStarted = false
    }

    func cancel() {
        writer?.cancelWriting()
        writer = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        sessionStarted = false
    }
}
