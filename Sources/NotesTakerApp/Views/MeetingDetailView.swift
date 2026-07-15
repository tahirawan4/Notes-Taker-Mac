import AppKit
import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingStore.self) private var store
    let meeting: Meeting
    @State private var exportMessage: String?
    @State private var processingMessage: String?
    @State private var copyMessage: String?
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                videoPanel

                TabView {
                    NotesOverview(meeting: meeting)
                        .tabItem { Label("Notes", systemImage: "doc.text") }
                    ActionItemsView(items: meeting.actionItems)
                        .tabItem { Label("Actions", systemImage: "checklist") }
                    TranscriptView(segments: meeting.transcript)
                        .tabItem { Label("Transcript", systemImage: "quote.bubble") }
                }
                .frame(minHeight: 420)
            }
            .padding(26)
        }
        .background(AppColors.canvas)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    StatusBadge(status: meeting.status)
                    Text(meeting.source.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppColors.surfaceAlt, in: Capsule())
                }
                Text(meeting.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text("\(meeting.startedAt.formatted(date: .complete, time: .shortened)) | \(formatDuration(meeting.duration))")
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            Menu {
                Button {
                    copyToClipboard(.notes)
                } label: {
                    Label("Copy Notes", systemImage: "doc.on.doc")
                }
                Button {
                    copyToClipboard(.actions)
                } label: {
                    Label("Copy Action Items", systemImage: "checklist")
                }
                Button {
                    copyToClipboard(.transcript)
                } label: {
                    Label("Copy Transcript", systemImage: "quote.bubble")
                }
                Divider()
                Button {
                    copyToClipboard(.fullDiscussion)
                } label: {
                    Label("Copy Full Discussion", systemImage: "rectangle.stack")
                }
            } label: {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)

            Menu {
                Button {
                    export(.notes)
                } label: {
                    Label("Meeting Notes PDF", systemImage: "doc.richtext")
                }
                Button {
                    export(.transcript)
                } label: {
                    Label("Full Transcript PDF", systemImage: "text.page")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            if canProcess {
                Button {
                    processRecording()
                } label: {
                    Label(isProcessing ? "Processing" : "Process Recording", systemImage: "waveform.badge.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(isProcessing)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .offset(y: 22)
            }
        }
    }

    private var videoPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.navy, .indigo.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if meeting.status == .ready,
               let videoPath = meeting.videoPath,
               FileManager.default.fileExists(atPath: videoPath) {
                savedRecordingView(path: videoPath)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: meeting.status == .failed ? "exclamationmark.triangle" : "video.badge.waveform")
                        .font(.system(size: 42, weight: .semibold))
                    Text(meeting.status == .failed ? "Recording failed" : "No video file saved")
                        .font(.title3.weight(.semibold))
                    Text(videoEmptyMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: 520)
                }
                .foregroundStyle(.white)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func savedRecordingView(path: String) -> some View {
        let url = URL(filePath: path)
        return VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 42, weight: .semibold))
            Text("Recording saved")
                .font(.title3.weight(.semibold))
            Text(url.lastPathComponent)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
            HStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open Recording", systemImage: "play.rectangle")
                }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .foregroundStyle(.white)
    }

    private var videoEmptyMessage: String {
        if meeting.status == .failed {
            return meeting.summary.first ?? "Check Screen Recording and Microphone permissions, then try again."
        }
        return "Start Capture will save a local screen recording here. Transcript and AI notes require transcription processing after recording."
    }

    private var canProcess: Bool {
        meeting.status == .ready &&
        meeting.videoPath != nil &&
        !isProcessing
    }

    private var statusMessage: String? {
        processingMessage ?? exportMessage ?? copyMessage
    }

    private func processRecording() {
        isProcessing = true
        processingMessage = "Processing recording..."
        store.updateMeetingStatus(id: meeting.id, status: .processing, summary: ["Processing recording for transcript and notes..."])

        Task {
            do {
                let processed = try await MeetingProcessingService().process(meeting)
                await MainActor.run {
                    store.upsert(processed)
                    processingMessage = "Transcript and notes generated"
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    var failed = meeting
                    failed.status = .failed
                    failed.summary = ["Processing failed: \(error.localizedDescription)"]
                    store.upsert(failed)
                    processingMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func export(_ kind: PDFExportKind) {
        do {
            let url = try PDFExporter.export(meeting: meeting, kind: kind)
            exportMessage = "Exported to \(url.lastPathComponent)"
            copyMessage = nil
        } catch is CancellationError {
            exportMessage = nil
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard(_ kind: ClipboardKind) {
        let value: String
        let label: String

        switch kind {
        case .notes:
            value = ClipboardFormatter.notes(from: meeting)
            label = "notes"
        case .actions:
            value = ClipboardFormatter.actions(from: meeting)
            label = "action items"
        case .transcript:
            value = ClipboardFormatter.transcript(from: meeting)
            label = "transcript"
        case .fullDiscussion:
            value = ClipboardFormatter.fullDiscussion(from: meeting)
            label = "discussion"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyMessage = "Copied \(label) to clipboard"
        exportMessage = nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        let hours = minutes / 60
        let remaining = minutes % 60
        return hours > 0 ? "\(hours)h \(remaining)m" : "\(minutes)m"
    }
}

private enum ClipboardKind {
    case notes
    case actions
    case transcript
    case fullDiscussion
}
