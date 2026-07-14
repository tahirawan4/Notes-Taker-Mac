import Foundation

enum MeetingSource: String, Codable, CaseIterable, Identifiable {
    case zoom = "Zoom"
    case chrome = "Chrome"
    case googleMeet = "Google Meet"
    case manual = "Manual"

    var id: String { rawValue }
}

enum MeetingStatus: String, Codable {
    case recording = "Recording"
    case processing = "Processing"
    case ready = "Ready"
    case failed = "Failed"
}

enum ActionPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum ActionStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case inProgress = "In Progress"
    case done = "Done"

    var id: String { rawValue }
}

struct TranscriptSegment: Identifiable, Codable, Hashable {
    var id = UUID()
    var startTime: TimeInterval
    var endTime: TimeInterval
    var speaker: String
    var text: String
}

struct MeetingActionItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var owner: String
    var task: String
    var dueDate: Date?
    var priority: ActionPriority
    var status: ActionStatus
    var evidenceTimestamp: TimeInterval?
}

struct Meeting: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var source: MeetingSource
    var status: MeetingStatus
    var videoPath: String?
    var audioPath: String?
    var summary: [String]
    var decisions: [String]
    var risks: [String]
    var openQuestions: [String]
    var actionItems: [MeetingActionItem]
    var transcript: [TranscriptSegment]
    var createdAt = Date()
    var updatedAt = Date()

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    static func starter(source: MeetingSource) -> Meeting {
        Meeting(
            title: "Meeting \(Date.now.formatted(date: .abbreviated, time: .shortened))",
            startedAt: Date(),
            endedAt: nil,
            source: source,
            status: .recording,
            videoPath: nil,
            audioPath: nil,
            summary: ["Recording is active. Notes will appear when processing is complete."],
            decisions: [],
            risks: [],
            openQuestions: [],
            actionItems: [],
            transcript: []
        )
    }

    static func blank(title: String, source: MeetingSource, startedAt: Date) -> Meeting {
        Meeting(
            title: title,
            startedAt: startedAt,
            endedAt: nil,
            source: source,
            status: .ready,
            videoPath: nil,
            audioPath: nil,
            summary: [],
            decisions: [],
            risks: [],
            openQuestions: [],
            actionItems: [],
            transcript: []
        )
    }

    static let sample = Meeting(
        title: "Product Roadmap Sync",
        startedAt: Date().addingTimeInterval(-3_900),
        endedAt: Date().addingTimeInterval(-300),
        source: .zoom,
        status: .ready,
        videoPath: nil,
        audioPath: nil,
        summary: [
            "The team aligned on launching the meeting notes MVP as a native macOS app.",
            "PDF export quality is a launch requirement, with separate notes and transcript exports.",
            "Manual recording will ship first, followed by Zoom and Chrome meeting detection."
        ],
        decisions: [
            "Use SwiftUI for the macOS app shell and meeting library.",
            "Store meeting records locally before adding cloud sync.",
            "Generate PDFs from structured meeting data instead of raw text."
        ],
        risks: [
            "System audio capture can require extra macOS permissions and careful user onboarding.",
            "Speaker labeling quality depends on transcription provider capabilities."
        ],
        openQuestions: [
            "Should transcription run locally, in the cloud, or as a user-selectable setting?",
            "Which export formats should follow PDF: DOCX, Markdown, or Notion?"
        ],
        actionItems: [
            MeetingActionItem(owner: "Tahir", task: "Validate manual capture flow on Zoom and Chrome.", dueDate: Date().addingTimeInterval(172_800), priority: .high, status: .open, evidenceTimestamp: 480),
            MeetingActionItem(owner: "Design", task: "Finalize PDF color palette and typography.", dueDate: Date().addingTimeInterval(259_200), priority: .medium, status: .inProgress, evidenceTimestamp: 920)
        ],
        transcript: [
            TranscriptSegment(startTime: 0, endTime: 12, speaker: "Tahir", text: "The main requirement is a Mac app that can record meetings and produce precise notes."),
            TranscriptSegment(startTime: 12, endTime: 28, speaker: "Product", text: "We should separate summary notes, action items, and the full transcript so each can be exported."),
            TranscriptSegment(startTime: 28, endTime: 48, speaker: "Engineering", text: "The right first step is manual capture with a reliable meeting library and polished PDF output.")
        ]
    )
}
