import XCTest
@testable import NotesTakerApp

final class RecordingStateMachineTests: XCTestCase {
    func testStartAndStopLifecycleReturnsToIdle() throws {
        let meetingID = UUID()
        var machine = RecordingStateMachine()

        try machine.beginStart(meetingID: meetingID)
        try machine.finishStart(meetingID: meetingID)
        XCTAssertEqual(try machine.beginStop(), meetingID)
        machine.finishStop(meetingID: meetingID)

        XCTAssertEqual(machine.state, .idle)
        XCTAssertFalse(machine.isActive)
    }

    func testDuplicateStartIsRejectedWhileStarting() throws {
        var machine = RecordingStateMachine()
        try machine.beginStart(meetingID: UUID())

        XCTAssertThrowsError(try machine.beginStart(meetingID: UUID())) { error in
            XCTAssertEqual(error as? RecordingStateMachineError, .alreadyRecording)
        }
    }

    func testStopWithoutRecordingIsRejected() {
        var machine = RecordingStateMachine()

        XCTAssertThrowsError(try machine.beginStop()) { error in
            XCTAssertEqual(error as? RecordingStateMachineError, .notRecording)
        }
    }
}
