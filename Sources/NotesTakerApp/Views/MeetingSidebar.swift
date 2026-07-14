import SwiftUI

struct MeetingSidebar: View {
    @Environment(MeetingStore.self) private var store
    @Binding var selectedID: Meeting.ID?
    @State private var searchText = ""
    @State private var isShowingNewMeeting = false

    private var filteredMeetings: [Meeting] {
        guard !searchText.isEmpty else { return store.meetings }
        return store.meetings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.source.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Meetings")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.text)
                    Text("\(store.meetings.count) saved records")
                        .foregroundStyle(AppColors.textMuted)
                }

                Spacer()

                Button {
                    isShowingNewMeeting = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .background(Color.teal.opacity(0.14), in: Circle())
                .foregroundStyle(.teal)
                .help("Add meeting")
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
        .sheet(isPresented: $isShowingNewMeeting) {
            NewMeetingView()
                .environment(store)
        }
    }
}

private struct NewMeetingView: View {
    @Environment(MeetingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var source: MeetingSource = .manual
    @State private var startedAt = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Meeting")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text("Create a meeting record for notes, transcript, actions, and PDF export.")
                    .foregroundStyle(AppColors.textMuted)
            }

            VStack(alignment: .leading, spacing: 14) {
                TextField("Meeting title", text: $title)
                    .textFieldStyle(.roundedBorder)

                Picker("Source", selection: $source) {
                    ForEach(MeetingSource.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                DatePicker("Started", selection: $startedAt)
            }
            .foregroundStyle(AppColors.text)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button {
                    store.addMeeting(title: title, source: source, startedAt: startedAt)
                    dismiss()
                } label: {
                    Label("Add Meeting", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(AppColors.canvas)
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
