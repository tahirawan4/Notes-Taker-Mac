import SwiftUI

struct RecordingToolbar: View {
    @Environment(MeetingStore.self) private var store
    @Environment(RecordingService.self) private var recorder
    @State private var source: MeetingSource = .zoom

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: recorder.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(recorder.isRecording ? .red : .teal)
                Text(recorder.isRecording ? "Recording \(format(recorder.elapsed))" : "Ready to capture")
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            Picker("Source", selection: $source) {
                ForEach(MeetingSource.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 420)
            .disabled(recorder.isRecording)

            Button {
                toggleRecording()
            } label: {
                Label(recorder.isRecording ? "Stop" : "Start Capture", systemImage: recorder.isRecording ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .red : .teal)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AppColors.toolbar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            if let meeting = recorder.stop() {
                store.upsert(meeting)
            }
        } else {
            let meeting = recorder.start(source: source)
            store.upsert(meeting)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
