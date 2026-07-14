import SwiftUI

struct ActionItemsView: View {
    let items: [MeetingActionItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if items.isEmpty {
                    ContentUnavailableView("No action items", systemImage: "checklist", description: Text("Action items will appear after processing."))
                } else {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            priorityDot(item.priority)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.task)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.text)
                                HStack(spacing: 14) {
                                    Label(item.owner, systemImage: "person")
                                    Label(item.status.rawValue, systemImage: "circle.dotted")
                                    if let dueDate = item.dueDate {
                                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                            }
                            Spacer()
                            Text(item.priority.rawValue)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(priorityColor(item.priority).opacity(0.16), in: Capsule())
                                .foregroundStyle(priorityColor(item.priority))
                        }
                        .padding(16)
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

    private func priorityDot(_ priority: ActionPriority) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }

    private func priorityColor(_ priority: ActionPriority) -> Color {
        switch priority {
        case .low: .teal
        case .medium: .amber
        case .high: .coral
        }
    }
}
