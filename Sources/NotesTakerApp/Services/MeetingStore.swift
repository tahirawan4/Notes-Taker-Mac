import Foundation
import Observation

@MainActor
@Observable
final class MeetingStore {
    var meetings: [Meeting] = []
    var selectedMeetingID: Meeting.ID? {
        didSet {
            saveSelectedMeetingID()
        }
    }

    private let fileURL: URL
    private let seedSampleOnMissing: Bool
    private let selectedMeetingDefaultsKey: String

    init(fileURL: URL? = nil, seedSampleOnMissing: Bool = true) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appURL = baseURL.appending(path: "NotesTaker", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
            self.fileURL = appURL.appending(path: "meetings.json")
        }
        self.seedSampleOnMissing = seedSampleOnMissing
        selectedMeetingDefaultsKey = "selectedMeetingID.\(self.fileURL.path)"
        load()
    }

    var selectedMeeting: Meeting? {
        get {
            guard let selectedMeetingID else { return meetings.first }
            return meetings.first { $0.id == selectedMeetingID }
        }
        set {
            selectedMeetingID = newValue?.id
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            meetings = seedSampleOnMissing ? [.sample] : []
            selectedMeetingID = meetings.first?.id
            save()
            return
        }

        do {
            meetings = try JSONDecoder.meetingDecoder.decode([Meeting].self, from: data)
            recoverInterruptedProcessing()
            selectedMeetingID = restoredSelectedMeetingID() ?? meetings.first?.id
            save()
        } catch {
            backupCorruptStore()
            meetings = seedSampleOnMissing ? [.sample] : []
            selectedMeetingID = meetings.first?.id
            save()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder.meetingEncoder.encode(meetings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Could not save meetings: \(error.localizedDescription)")
        }
    }

    func upsert(_ meeting: Meeting) {
        var updated = meeting
        updated.updatedAt = Date()

        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = updated
        } else {
            meetings.insert(updated, at: 0)
        }

        selectedMeetingID = updated.id
        save()
    }

    func replace(_ meeting: Meeting, select: Bool) {
        var updated = meeting
        updated.updatedAt = Date()

        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = updated
        } else {
            meetings.insert(updated, at: 0)
        }

        if select {
            selectedMeetingID = updated.id
        }
        save()
    }

    func updateMeetingStatus(id: Meeting.ID, status: MeetingStatus, summary: [String]? = nil) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else {
            return
        }
        meetings[index].status = status
        meetings[index].updatedAt = Date()
        if let summary {
            meetings[index].summary = summary
        }
        save()
    }

    func updateProcessing(id: Meeting.ID, message: String, progress: Double, status: MeetingStatus = .processing) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else {
            return
        }
        meetings[index].status = status
        meetings[index].processingMessage = message
        meetings[index].processingProgress = min(max(progress, 0), 1)
        meetings[index].updatedAt = Date()
        save()
    }

    func clearProcessing(id: Meeting.ID) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else {
            return
        }
        meetings[index].processingMessage = nil
        meetings[index].processingProgress = nil
        meetings[index].updatedAt = Date()
        save()
    }

    func resetProcessing(id: Meeting.ID, message: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else {
            return
        }
        meetings[index].status = .ready
        if shouldReplaceProcessingSummary(meetings[index].summary) {
            meetings[index].summary = [message]
        }
        meetings[index].processingMessage = message
        meetings[index].processingProgress = 0
        meetings[index].updatedAt = Date()
        save()
    }

    func updateManualNotes(id: Meeting.ID, notes: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else {
            return
        }
        meetings[index].manualNotes = notes
        meetings[index].updatedAt = Date()
        save()
    }

    func addMeeting(title: String, source: MeetingSource, startedAt: Date) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let meeting = Meeting.blank(
            title: cleanTitle.isEmpty ? "Untitled Meeting" : cleanTitle,
            source: source,
            startedAt: startedAt
        )
        upsert(meeting)
    }

    func deleteMeeting(id: Meeting.ID) {
        meetings.removeAll { $0.id == id }
        if selectedMeetingID == id {
            selectedMeetingID = meetings.first?.id
        }
        save()
    }

    private func recoverInterruptedProcessing() {
        for index in meetings.indices where meetings[index].status == .processing {
            meetings[index].status = .ready
            if shouldReplaceProcessingSummary(meetings[index].summary) {
                meetings[index].summary = [
                    "Processing was interrupted because NotesTaker was closed. Press Process Recording to restart."
                ]
            }
            meetings[index].processingMessage = "Processing was interrupted because NotesTaker was closed. Press Process Recording to restart."
            meetings[index].processingProgress = 0
            meetings[index].updatedAt = Date()
        }
    }

    private func shouldReplaceProcessingSummary(_ summary: [String]) -> Bool {
        guard let first = summary.first?.lowercased() else {
            return true
        }
        return summary.isEmpty || first.contains("processing")
    }

    private func restoredSelectedMeetingID() -> Meeting.ID? {
        guard
            let rawValue = UserDefaults.standard.string(forKey: selectedMeetingDefaultsKey),
            let id = Meeting.ID(uuidString: rawValue),
            meetings.contains(where: { $0.id == id })
        else {
            return nil
        }
        return id
    }

    private func saveSelectedMeetingID() {
        if let selectedMeetingID {
            UserDefaults.standard.set(selectedMeetingID.uuidString, forKey: selectedMeetingDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedMeetingDefaultsKey)
        }
    }

    private func backupCorruptStore() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        let formatter = ISO8601DateFormatter()
        let backupURL = fileURL.deletingLastPathComponent()
            .appending(path: "meetings-corrupt-\(formatter.string(from: Date())).json")
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
    }
}

private extension JSONEncoder {
    static var meetingEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var meetingDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
