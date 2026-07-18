import XCTest
@testable import NotesTakerApp

@MainActor
final class MeetingStoreTests: XCTestCase {
    func testMissingStoreCanStartEmptyForTests() {
        let fileURL = temporaryFileURL()

        let store = MeetingStore(fileURL: fileURL, seedSampleOnMissing: false)

        XCTAssertTrue(store.meetings.isEmpty)
        XCTAssertNil(store.selectedMeetingID)
    }

    func testCorruptStoreIsBackedUpBeforeReset() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "meetings.json")
        try Data("not json".utf8).write(to: fileURL)

        let store = MeetingStore(fileURL: fileURL, seedSampleOnMissing: false)
        let backupFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("meetings-corrupt-") }

        XCTAssertTrue(store.meetings.isEmpty)
        XCTAssertEqual(backupFiles.count, 1)
    }

    func testSelectionRestoresWhenSavedMeetingStillExists() {
        let fileURL = temporaryFileURL()
        var first = Meeting.blank(title: "First", source: .manual, startedAt: Date())
        var second = Meeting.blank(title: "Second", source: .zoom, startedAt: Date())
        first.id = UUID()
        second.id = UUID()

        let store = MeetingStore(fileURL: fileURL, seedSampleOnMissing: false)
        store.upsert(first)
        store.upsert(second)
        store.selectedMeetingID = first.id

        let restored = MeetingStore(fileURL: fileURL, seedSampleOnMissing: false)

        XCTAssertEqual(restored.selectedMeetingID, first.id)
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "meetings.json")
    }
}
