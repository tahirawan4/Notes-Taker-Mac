import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if segments.isEmpty {
                    ContentUnavailableView("No transcript", systemImage: "text.quote", description: Text("Transcription output will appear here."))
                } else {
                    ForEach(segments) { segment in
                        HStack(alignment: .top, spacing: 16) {
                            Text(timestamp(segment.startTime))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.teal)
                                .frame(width: 52, alignment: .leading)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(segment.speaker)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.text)
                                Text(segment.text)
                                    .foregroundStyle(AppColors.text)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
