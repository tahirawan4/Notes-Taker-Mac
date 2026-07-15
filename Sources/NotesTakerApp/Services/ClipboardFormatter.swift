import Foundation

enum ClipboardFormatter {
    static func manualNotes(from meeting: Meeting) -> String {
        let notes = meeting.manualNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            header(for: meeting, title: "My Notes"),
            notes.isEmpty ? "No personal notes yet." : notes
        ].joined(separator: "\n\n")
    }

    static func notes(from meeting: Meeting) -> String {
        [
            header(for: meeting, title: "Meeting Notes"),
            manualNotesSection(from: meeting),
            section("Executive Summary", items: meeting.summary),
            section("Decisions", items: meeting.decisions),
            section("Risks & Blockers", items: meeting.risks),
            section("Open Questions", items: meeting.openQuestions)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    static func actions(from meeting: Meeting) -> String {
        let lines = meeting.actionItems.map { item in
            var detail = "- [\(item.status.rawValue)] \(item.task)"
            detail += " | Owner: \(item.owner)"
            detail += " | Priority: \(item.priority.rawValue)"
            if let dueDate = item.dueDate {
                detail += " | Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
            }
            return detail
        }

        return [
            header(for: meeting, title: "Action Items"),
            lines.isEmpty ? "No action items yet." : lines.joined(separator: "\n")
        ].joined(separator: "\n\n")
    }

    static func transcript(from meeting: Meeting) -> String {
        let lines = meeting.transcript.map { segment in
            "[\(timestamp(segment.startTime))] \(segment.speaker): \(segment.text)"
        }

        return [
            header(for: meeting, title: "Transcript"),
            lines.isEmpty ? "No transcript yet." : lines.joined(separator: "\n")
        ].joined(separator: "\n\n")
    }

    static func fullDiscussion(from meeting: Meeting) -> String {
        [
            notes(from: meeting),
            actions(from: meeting),
            transcript(from: meeting)
        ].joined(separator: "\n\n---\n\n")
    }

    private static func header(for meeting: Meeting, title: String) -> String {
        """
        \(title)
        \(meeting.title)
        \(meeting.source.rawValue) | \(meeting.startedAt.formatted(date: .abbreviated, time: .shortened)) | \(formatDuration(meeting.duration))
        """
    }

    private static func section(_ title: String, items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        return "\(title)\n" + items.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func manualNotesSection(from meeting: Meeting) -> String {
        let notes = meeting.manualNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return "" }
        return "My Notes\n\(notes)"
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        let hours = minutes / 60
        let remaining = minutes % 60
        return hours > 0 ? "\(hours)h \(remaining)m" : "\(minutes)m"
    }
}
