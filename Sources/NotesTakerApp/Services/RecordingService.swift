import Foundation
import Observation

@MainActor
@Observable
final class RecordingService {
    private(set) var activeMeeting: Meeting?
    private(set) var elapsed: TimeInterval = 0

    private var timer: Timer?

    var isRecording: Bool {
        activeMeeting != nil
    }

    func start(source: MeetingSource) -> Meeting {
        let meeting = Meeting.starter(source: source)
        activeMeeting = meeting
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsed += 1
            }
        }
        return meeting
    }

    func stop() -> Meeting? {
        guard var meeting = activeMeeting else { return nil }
        meeting.endedAt = Date()
        meeting.status = .ready
        meeting.summary = [
            "Recording completed and is ready for transcription processing.",
            "This build includes the meeting library and export pipeline; native ScreenCaptureKit capture can be connected in this service."
        ]
        meeting.decisions = ["Manual capture flow was completed for this meeting record."]
        meeting.actionItems = [
            MeetingActionItem(owner: "You", task: "Connect transcription provider and process this recording.", dueDate: nil, priority: .high, status: .open, evidenceTimestamp: nil)
        ]
        meeting.transcript = [
            TranscriptSegment(startTime: 0, endTime: max(1, elapsed), speaker: "System", text: "Recording placeholder created. Attach the captured audio transcription here.")
        ]

        activeMeeting = nil
        elapsed = 0
        timer?.invalidate()
        timer = nil
        return meeting
    }
}
