import Foundation
import Observation

@MainActor
@Observable
final class RecordingService {
    private(set) var activeMeeting: Meeting?
    private(set) var elapsed: TimeInterval = 0
    private(set) var lastError: String?

    private let movieRecorder = ScreenMovieRecorder()
    private var timer: Timer?

    var isRecording: Bool {
        activeMeeting != nil
    }

    func start(source: MeetingSource, target: CaptureTarget = .mainDisplay()) async -> Meeting {
        var meeting = Meeting.starter(source: source)
        lastError = nil

        do {
            let outputURL = try recordingsDirectory()
                .appending(path: "\(meeting.id.uuidString).mov")
            try await movieRecorder.start(to: outputURL, target: target)
            activeMeeting = meeting
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
            timer?.invalidate()
            timer = nil
            return meeting
        }
    }

    func stop() async -> Meeting? {
        guard var meeting = activeMeeting else { return nil }
        meeting.endedAt = Date()

        do {
            let url = try await movieRecorder.stop()
            meeting.videoPath = url.path
            meeting.status = .ready
            meeting.summary = [
                "Screen recording was saved successfully.",
                "Transcript and AI notes are not generated yet. Connect a transcription provider next to process the recording into notes and action items."
            ]
            meeting.decisions = []
            meeting.actionItems = [
                MeetingActionItem(owner: "You", task: "Transcribe this saved recording and generate meeting notes.", dueDate: nil, priority: .high, status: .open, evidenceTimestamp: nil)
            ]
            meeting.transcript = []
            lastError = nil
        } catch {
            meeting.status = .failed
            meeting.summary = ["Recording stopped, but saving failed: \(error.localizedDescription)"]
            lastError = error.localizedDescription
        }

        activeMeeting = nil
        elapsed = 0
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
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = baseURL
            .appending(path: "NotesTaker", directoryHint: .isDirectory)
            .appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
