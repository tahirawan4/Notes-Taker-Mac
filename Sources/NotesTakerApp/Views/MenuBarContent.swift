import SwiftUI

struct MenuBarContent: View {
    @Environment(MeetingStore.self) private var store
    @Environment(RecordingService.self) private var recorder

    var body: some View {
        VStack {
            if recorder.isRecording {
                Text("Recording \(format(recorder.elapsed))")
                Button("Stop Recording") {
                    Task {
                        if let meeting = await recorder.stop() {
                            store.upsert(meeting)
                        }
                    }
                }
            } else {
                if let lastError = recorder.lastError {
                    Text(lastError)
                }
                Button("Start Zoom Capture") {
                    Task {
                        store.upsert(await recorder.start(source: .zoom))
                    }
                }
                Button("Start Chrome Capture") {
                    Task {
                        store.upsert(await recorder.start(source: .chrome))
                    }
                }
            }
            Divider()
            Button("Quit NotesTaker") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
