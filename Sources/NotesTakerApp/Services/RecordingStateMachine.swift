import Foundation

enum RecordingStateMachineError: LocalizedError, Equatable {
    case alreadyRecording
    case notRecording
    case invalidTransition(from: RecordingStateMachine.State, to: RecordingStateMachine.State)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "A recording is already active."
        case .notRecording:
            "There is no active recording to stop."
        case .invalidTransition:
            "Recording moved through an unexpected state."
        }
    }
}

struct RecordingStateMachine {
    enum State: Equatable {
        case idle
        case starting(UUID)
        case recording(UUID)
        case stopping(UUID)
    }

    private(set) var state: State = .idle

    var isActive: Bool {
        state != .idle
    }

    mutating func beginStart(meetingID: UUID) throws {
        guard state == .idle else {
            throw RecordingStateMachineError.alreadyRecording
        }
        state = .starting(meetingID)
    }

    mutating func finishStart(meetingID: UUID) throws {
        guard state == .starting(meetingID) else {
            throw RecordingStateMachineError.invalidTransition(from: state, to: .recording(meetingID))
        }
        state = .recording(meetingID)
    }

    mutating func failStart(meetingID: UUID) {
        guard state == .starting(meetingID) else {
            return
        }
        state = .idle
    }

    mutating func beginStop() throws -> UUID {
        guard case .recording(let meetingID) = state else {
            if state == .idle {
                throw RecordingStateMachineError.notRecording
            }
            throw RecordingStateMachineError.invalidTransition(from: state, to: state)
        }
        state = .stopping(meetingID)
        return meetingID
    }

    mutating func finishStop(meetingID: UUID) {
        guard state == .stopping(meetingID) else {
            return
        }
        state = .idle
    }
}
