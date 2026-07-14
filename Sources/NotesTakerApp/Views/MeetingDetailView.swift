import AVKit
import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingStore.self) private var store
    let meeting: Meeting
    @State private var exportMessage: String?

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
        }
        .overlay(alignment: .bottomTrailing) {
            if let exportMessage {
                Text(exportMessage)
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
            if let videoPath = meeting.videoPath, FileManager.default.fileExists(atPath: videoPath) {
                VideoPlayer(player: AVPlayer(url: URL(filePath: videoPath)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private var videoEmptyMessage: String {
        if meeting.status == .failed {
            return meeting.summary.first ?? "Check Screen Recording and Microphone permissions, then try again."
        }
        return "Start Capture will save a local screen recording here. Transcript and AI notes require transcription processing after recording."
    }

    private func export(_ kind: PDFExportKind) {
        do {
            let url = try PDFExporter.export(meeting: meeting, kind: kind)
            exportMessage = "Exported to \(url.lastPathComponent)"
        } catch is CancellationError {
            exportMessage = nil
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        let hours = minutes / 60
        let remaining = minutes % 60
        return hours > 0 ? "\(hours)h \(remaining)m" : "\(minutes)m"
    }
}
