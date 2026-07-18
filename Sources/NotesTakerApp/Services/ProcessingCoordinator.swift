import Foundation
import Observation

@MainActor
@Observable
final class ProcessingCoordinator {
    private var tasks: [Meeting.ID: Task<Void, Never>] = [:]
    private(set) var runningMeetingIDs: Set<Meeting.ID> = []

    func isProcessing(_ meetingID: Meeting.ID) -> Bool {
        runningMeetingIDs.contains(meetingID)
    }

    func process(_ meeting: Meeting, store: MeetingStore) {
        cancelTaskOnly(for: meeting.id)
        runningMeetingIDs.insert(meeting.id)
        store.updateProcessing(id: meeting.id, message: "Preparing recording for processing...", progress: 0.05)

        tasks[meeting.id] = Task {
            do {
                let processed = try await MeetingProcessingService().process(meeting) { update in
                    await MainActor.run {
                        store.updateProcessing(id: meeting.id, message: update.message, progress: update.fraction)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    var final = processed
                    final.processingMessage = nil
                    final.processingProgress = nil
                    store.replace(final, select: false)
                    finishTask(for: meeting.id)
                }
            } catch is CancellationError {
                await MainActor.run {
                    store.resetProcessing(id: meeting.id, message: "Processing was stopped. Press Process Recording to restart.")
                    finishTask(for: meeting.id)
                }
            } catch {
                await MainActor.run {
                    var failed = meeting
                    failed.status = .failed
                    failed.summary = ["Processing failed: \(error.localizedDescription)"]
                    failed.processingMessage = error.localizedDescription
                    failed.processingProgress = 0
                    store.replace(failed, select: false)
                    finishTask(for: meeting.id)
                }
            }
        }
    }

    func stopProcessing(_ meetingID: Meeting.ID, store: MeetingStore) {
        cancelTaskOnly(for: meetingID)
        store.resetProcessing(id: meetingID, message: "Processing was stopped. Press Process Recording to restart.")
    }

    private func cancelTaskOnly(for meetingID: Meeting.ID) {
        tasks[meetingID]?.cancel()
        tasks[meetingID] = nil
        runningMeetingIDs.remove(meetingID)
    }

    private func finishTask(for meetingID: Meeting.ID) {
        tasks[meetingID] = nil
        runningMeetingIDs.remove(meetingID)
    }
}
