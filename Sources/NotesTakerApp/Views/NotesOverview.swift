import AppKit
import SwiftUI

struct NotesOverview: View {
    let meeting: Meeting

    var body: some View {
        ScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    SectionPanel(title: "Executive Summary", icon: "sparkles", color: .teal, items: meeting.summary)
                    SectionPanel(title: "Decisions", icon: "checkmark.seal", color: .indigo, items: meeting.decisions)
                }
                GridRow {
                    SectionPanel(title: "Risks & Blockers", icon: "exclamationmark.triangle", color: .coral, items: meeting.risks)
                    SectionPanel(title: "Open Questions", icon: "questionmark.circle", color: .amber, items: meeting.openQuestions)
                }
            }
            .padding(.top, 16)
        }
    }
}

private struct SectionPanel: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Spacer()
                Button {
                    copySection()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(didCopy ? .teal : AppColors.textMuted)
                .background((didCopy ? Color.teal : Color.black).opacity(didCopy ? 0.12 : 0.05), in: Circle())
                .help("Copy \(title)")
                .disabled(items.isEmpty)
            }

            if items.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(AppColors.textMuted)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(item)
                            .foregroundStyle(AppColors.text)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private func copySection() {
        let value = "\(title)\n" + items.map { "- \($0)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        didCopy = true

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                didCopy = false
            }
        }
    }
}
