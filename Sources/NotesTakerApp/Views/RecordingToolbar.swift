import SwiftUI

struct RecordingToolbar: View {
    @Environment(MeetingStore.self) private var store
    @Environment(RecordingService.self) private var recorder
    @Environment(AISettingsStore.self) private var aiSettings
    @State private var source: MeetingSource = .zoom
    @State private var isShowingAISettings = false
    @State private var isShowingCapturePicker = false
    @State private var processingTasks: [Meeting.ID: Task<Void, Never>] = [:]

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
                            .lineLimit(2)
                            .foregroundStyle(.coral)
                            .help(lastError)
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
                isShowingAISettings = true
            } label: {
                Image(systemName: aiSettings.snapshot.isAIEnabled ? "sparkles" : "gearshape")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(aiSettings.snapshot.isAIEnabled ? .indigo : AppColors.textMuted)
            .help("AI notes settings")

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
        .sheet(isPresented: $isShowingAISettings) {
            AISettingsView()
                .environment(aiSettings)
        }
        .sheet(isPresented: $isShowingCapturePicker) {
            CaptureSourcePickerView(meetingSource: source) { target in
                startRecording(target: target)
            }
        }
        .onChange(of: store.selectedMeeting?.source) { _, newSource in
            if let newSource, !recorder.isRecording {
                source = newSource
            }
        }
    }

    private func toggleRecording() {
        Task {
            if recorder.isRecording {
                if let meeting = await recorder.stop() {
                    store.upsert(meeting)
                    processMeetingInBackground(meeting)
                }
            } else {
                isShowingCapturePicker = true
            }
        }
    }

    private func startRecording(target: CaptureTarget) {
        Task {
            let meeting = await recorder.start(meeting: store.selectedMeeting, source: source, target: target)
            store.upsert(meeting)
        }
    }

    private func processMeetingInBackground(_ meeting: Meeting) {
        processingTasks[meeting.id]?.cancel()
        store.updateProcessing(id: meeting.id, message: "Preparing recording for processing...", progress: 0.05)

        processingTasks[meeting.id] = Task {
            do {
                let processed = try await MeetingProcessingService().process(meeting) { update in
                    await MainActor.run {
                        store.updateProcessing(id: meeting.id, message: update.message, progress: update.fraction)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    var final = processed
                    final.processingMessage = nil
                    final.processingProgress = nil
                    store.replace(final, select: false)
                    processingTasks[meeting.id] = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    store.resetProcessing(id: meeting.id, message: "Processing was stopped. Press Process Recording to restart.")
                    processingTasks[meeting.id] = nil
                }
            } catch {
                await MainActor.run {
                    var failed = meeting
                    failed.status = .failed
                    failed.summary = ["Processing failed: \(error.localizedDescription)"]
                    failed.processingMessage = error.localizedDescription
                    failed.processingProgress = 0
                    store.replace(failed, select: false)
                    processingTasks[meeting.id] = nil
                }
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
