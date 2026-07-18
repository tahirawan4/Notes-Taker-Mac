import Foundation
import Observation

@MainActor
@Observable
final class RecordingService {
    private(set) var activeMeeting: Meeting?
    private(set) var elapsed: TimeInterval = 0
    private(set) var lastError: String?

    private let movieRecorder = ScreenMovieRecorder()
    private var lifecycle = RecordingStateMachine()
    private var timer: Timer?

    var isRecording: Bool {
        lifecycle.isActive
    }

    func start(meeting existingMeeting: Meeting?, source: MeetingSource, target: CaptureTarget = .mainDisplay()) async -> Meeting {
        if lifecycle.isActive {
            lastError = RecordingStateMachineError.alreadyRecording.localizedDescription
            return activeMeeting ?? existingMeeting ?? Meeting.starter(source: source)
        }

        var meeting = existingMeeting ?? Meeting.starter(source: source)
        meeting.source = source
        meeting.status = .recording
        meeting.startedAt = existingMeeting?.startedAt ?? Date()
        meeting.endedAt = nil
        meeting.videoPath = nil
        meeting.audioPath = nil
        meeting.processingMessage = nil
        meeting.processingProgress = nil
        lastError = nil

        do {
            try lifecycle.beginStart(meetingID: meeting.id)
            let outputURL = try recordingsDirectory()
                .appending(path: "\(meeting.id.uuidString).mov")
            try await movieRecorder.start(to: outputURL, target: target)
            activeMeeting = meeting
            try lifecycle.finishStart(meetingID: meeting.id)
            elapsed = 0
            startTimer()
            return meeting
        } catch {
            NSLog("[NotesTaker] RecordingService start failed: %@", String(describing: error))
            meeting.status = .failed
            meeting.summary = ["Recording could not start: \(error.localizedDescription)"]
            lastError = error.localizedDescription
            activeMeeting = nil
            elapsed = 0
            lifecycle.failStart(meetingID: meeting.id)
            timer?.invalidate()
            timer = nil
            return meeting
        }
    }

    func start(source: MeetingSource, target: CaptureTarget = .mainDisplay()) async -> Meeting {
        await start(meeting: nil, source: source, target: target)
    }

    func stop() async -> Meeting? {
        guard var meeting = activeMeeting else {
            lastError = RecordingStateMachineError.notRecording.localizedDescription
            return nil
        }

        do {
            _ = try lifecycle.beginStop()
        } catch {
            lastError = error.localizedDescription
            return meeting
        }

        meeting.endedAt = Date()

        do {
            let url = try await movieRecorder.stop()
            meeting.videoPath = url.path
            meeting.status = .ready
            meeting.processingMessage = "Recording saved. Starting transcription..."
            meeting.processingProgress = 0.02
            lastError = nil
        } catch {
            meeting.status = .failed
            meeting.summary = ["Recording stopped, but saving failed: \(error.localizedDescription)"]
            lastError = error.localizedDescription
        }

        activeMeeting = nil
        elapsed = 0
        lifecycle.finishStop(meetingID: meeting.id)
        timer?.invalidate()
        timer = nil
        return meeting
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsed += 1
            }
        }
    }

    private func recordingsDirectory() throws -> URL {
        let baseURL = try FileManager.default.applicationSupportURL()
        let url = baseURL
            .appending(path: "NotesTaker", directoryHint: .isDirectory)
            .appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
