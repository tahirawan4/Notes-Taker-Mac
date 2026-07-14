import Foundation
import Observation

@MainActor
@Observable
final class MeetingStore {
    var meetings: [Meeting] = []
    var selectedMeetingID: Meeting.ID?

    private let fileURL: URL

    init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appURL = baseURL.appending(path: "NotesTaker", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        fileURL = appURL.appending(path: "meetings.json")
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
            meetings = [.sample]
            selectedMeetingID = meetings.first?.id
            save()
            return
        }

        do {
            meetings = try JSONDecoder.meetingDecoder.decode([Meeting].self, from: data)
            selectedMeetingID = meetings.first?.id
        } catch {
            meetings = [.sample]
            selectedMeetingID = meetings.first?.id
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

    func addMeeting(title: String, source: MeetingSource, startedAt: Date) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let meeting = Meeting.blank(
            title: cleanTitle.isEmpty ? "Untitled Meeting" : cleanTitle,
            source: source,
            startedAt: startedAt
        )
        upsert(meeting)
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
