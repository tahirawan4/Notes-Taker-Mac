import SwiftUI

@main
struct NotesTakerApp: App {
    @State private var store = MeetingStore()
    @State private var recorder = RecordingService()
    @State private var aiSettings = AISettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(recorder)
                .environment(aiSettings)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("NotesTaker", systemImage: recorder.isRecording ? "record.circle.fill" : "waveform.and.mic") {
            MenuBarContent()
                .environment(store)
                .environment(recorder)
                .environment(aiSettings)
        }
    }
}
