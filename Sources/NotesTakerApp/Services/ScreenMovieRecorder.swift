import AVFoundation
import CoreGraphics
import Foundation

enum ScreenMovieRecorderError: LocalizedError {
    case screenPermissionDenied
    case noScreenInput
    case noMovieOutput
    case startFailed
    case stopFailed

    var errorDescription: String? {
        switch self {
        case .screenPermissionDenied:
            "Screen Recording permission is required. Enable it in System Settings > Privacy & Security > Screen & System Audio Recording."
        case .noScreenInput:
            "Could not create a screen capture input for the main display."
        case .noMovieOutput:
            "Could not create a movie recording output."
        case .startFailed:
            "The recording could not be started."
        case .stopFailed:
            "The recording could not be stopped cleanly."
        }
    }
}

@MainActor
final class ScreenMovieRecorder: NSObject, @preconcurrency AVCaptureFileOutputRecordingDelegate {
    private var session: AVCaptureSession?
    private var output: AVCaptureMovieFileOutput?
    private var outputURL: URL?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var stopContinuation: CheckedContinuation<URL, Error>?

    var isRecording: Bool {
        output?.isRecording == true
    }

    func start(to url: URL) async throws {
        guard preflightScreenCaptureAccess() else {
            throw ScreenMovieRecorderError.screenPermissionDenied
        }

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID()) else {
            throw ScreenMovieRecorderError.noScreenInput
        }
        screenInput.capturesCursor = true
        screenInput.capturesMouseClicks = true
        screenInput.minFrameDuration = CMTime(value: 1, timescale: 30)

        guard session.canAddInput(screenInput) else {
            throw ScreenMovieRecorderError.noScreenInput
        }
        session.addInput(screenInput)

        if await requestMicrophoneAccess(),
           let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            throw ScreenMovieRecorderError.noMovieOutput
        }
        session.addOutput(output)

        try? FileManager.default.removeItem(at: url)
        self.session = session
        self.output = output
        self.outputURL = url

        session.startRunning()

        try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stop() async throws -> URL {
        guard let output, output.isRecording else {
            if let outputURL {
                return outputURL
            }
            throw ScreenMovieRecorderError.stopFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            stopContinuation = continuation
            output.stopRecording()
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        startContinuation?.resume()
        startContinuation = nil
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        session?.stopRunning()
        session = nil
        self.output = nil

        if let error {
            startContinuation?.resume(throwing: error)
            stopContinuation?.resume(throwing: error)
        } else {
            stopContinuation?.resume(returning: outputFileURL)
        }

        startContinuation = nil
        stopContinuation = nil
    }

    private func preflightScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
