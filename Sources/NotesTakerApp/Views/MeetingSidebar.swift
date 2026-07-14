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

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredMeetings) { meeting in
                        MeetingRow(
                            meeting: meeting,
                            isSelected: selectedID == meeting.id,
                            onDelete: {
                                store.deleteMeeting(id: meeting.id)
                            }
                        )
                        .onTapGesture {
                            selectedID = meeting.id
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
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
    @FocusState private var isTitleFocused: Bool

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
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTitleFocused ? Color.teal : Color.black.opacity(0.12), lineWidth: isTitleFocused ? 2 : 1)
                    }
                    .focused($isTitleFocused)

                Picker("Source", selection: $source) {
                    ForEach(MeetingSource.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                DatePicker("Started", selection: $startedAt)
            }

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
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let isSelected: Bool
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(titleColor)
                Spacer()
                StatusBadge(status: meeting.status, isOnSelectedRow: isSelected)
                Button {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(deleteColor)
                .background(deleteBackground, in: Circle())
                .help("Delete meeting")
            }

            HStack(spacing: 8) {
                Label(meeting.source.rawValue, systemImage: sourceIcon)
                Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(detailColor)

            HStack(spacing: 12) {
                Label(formatDuration(meeting.duration), systemImage: "clock")
                Label("\(meeting.actionItems.count)", systemImage: "checklist")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(detailColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Delete this meeting?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Meeting", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the meeting from your local history. Saved recording files are not deleted.")
        }
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

    private var rowBackground: Color {
        isSelected ? .softNavy : AppColors.sidebar
    }

    private var rowBorder: Color {
        isSelected ? Color.teal.opacity(0.45) : Color.clear
    }

    private var titleColor: Color {
        isSelected ? .white : AppColors.text
    }

    private var detailColor: Color {
        isSelected ? Color.white.opacity(0.78) : AppColors.textMuted
    }

    private var deleteColor: Color {
        isSelected ? Color.white.opacity(0.9) : .coral
    }

    private var deleteBackground: Color {
        isSelected ? Color.white.opacity(0.12) : Color.coral.opacity(0.12)
    }
}

struct StatusBadge: View {
    let status: MeetingStatus
    var isOnSelectedRow = false

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
    }

    private var color: Color {
        switch status {
        case .recording: .red
        case .processing: .orange
        case .ready: .teal
        case .failed: .pink
        }
    }

    private var backgroundColor: Color {
        isOnSelectedRow ? Color.white.opacity(0.16) : color.opacity(0.16)
    }

    private var foregroundColor: Color {
        isOnSelectedRow ? .white : color
    }
}
