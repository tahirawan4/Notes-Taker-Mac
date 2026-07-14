import SwiftUI

struct RecordingToolbar: View {
    @Environment(MeetingStore.self) private var store
    @Environment(RecordingService.self) private var recorder
    @State private var source: MeetingSource = .zoom

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: recorder.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.isRecording ? "Recording \(format(recorder.elapsed))" : "Ready to capture")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    if let lastError = recorder.lastError {
                        Text(lastError)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.coral)
                    }
                }
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
        Task {
            if recorder.isRecording {
                if let meeting = await recorder.stop() {
                    store.upsert(meeting)
                }
            } else {
                let meeting = await recorder.start(source: source)
                store.upsert(meeting)
            }
        }
    }

    private var statusColor: Color {
        if recorder.lastError != nil {
            return .coral
        }
        return recorder.isRecording ? .red : .teal
    }

    private func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
