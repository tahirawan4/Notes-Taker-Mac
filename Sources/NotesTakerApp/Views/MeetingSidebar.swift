import SwiftUI

struct MeetingSidebar: View {
    @Environment(MeetingStore.self) private var store
    @Binding var selectedID: Meeting.ID?
    @State private var searchText = ""

    private var filteredMeetings: [Meeting] {
        guard !searchText.isEmpty else { return store.meetings }
        return store.meetings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.source.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Meetings")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text("\(store.meetings.count) saved records")
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)

            TextField("Search meetings", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 18)

            List(filteredMeetings, selection: $selectedID) { meeting in
                MeetingRow(meeting: meeting)
                    .tag(meeting.id)
            }
            .listStyle(.sidebar)
        }
        .background(AppColors.sidebar)
        .preferredColorScheme(.light)
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(AppColors.text)
                Spacer()
                StatusBadge(status: meeting.status)
            }

            HStack(spacing: 8) {
                Label(meeting.source.rawValue, systemImage: sourceIcon)
                Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(AppColors.textMuted)

            HStack(spacing: 12) {
                Label(formatDuration(meeting.duration), systemImage: "clock")
                Label("\(meeting.actionItems.count)", systemImage: "checklist")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.textMuted)
        }
        .padding(.vertical, 8)
    }

    private var sourceIcon: String {
        switch meeting.source {
        case .zoom: "video.fill"
        case .chrome, .googleMeet: "globe"
        case .manual: "rectangle.dashed"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        return "\(minutes)m"
    }
}

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .recording: .red
        case .processing: .orange
        case .ready: .teal
        case .failed: .pink
        }
    }
}
