import XCTest
@testable import NotesTakerApp

final class ClipboardFormatterTests: XCTestCase {
    func testActionsIncludeStatusOwnerPriorityAndDueDate() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let meeting = Meeting(
            title: "Planning",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_003_600),
            source: .zoom,
            status: .ready,
            videoPath: nil,
            audioPath: nil,
            summary: [],
            decisions: [],
            risks: [],
            openQuestions: [],
            manualNotes: "",
            actionItems: [
                MeetingActionItem(
                    owner: "Tahir",
                    task: "Share launch checklist.",
                    dueDate: dueDate,
                    priority: .high,
                    status: .open,
                    evidenceTimestamp: nil
                )
            ],
            transcript: [],
            processingMessage: nil,
            processingProgress: nil
        )

        let output = ClipboardFormatter.actions(from: meeting)

        XCTAssertTrue(output.contains("Action Items"))
        XCTAssertTrue(output.contains("- [Open] Share launch checklist."))
        XCTAssertTrue(output.contains("Owner: Tahir"))
        XCTAssertTrue(output.contains("Priority: High"))
        XCTAssertTrue(output.contains("Due:"))
    }
}
