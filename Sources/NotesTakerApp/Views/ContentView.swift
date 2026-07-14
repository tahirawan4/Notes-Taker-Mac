import SwiftUI

struct ContentView: View {
    @Environment(MeetingStore.self) private var store
    @Environment(RecordingService.self) private var recorder

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            RecordingToolbar()
                .environment(store)
                .environment(recorder)

            NavigationSplitView {
                MeetingSidebar(selectedID: $store.selectedMeetingID)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 340)
            } detail: {
                if let meeting = store.selectedMeeting {
                    MeetingDetailView(meeting: meeting)
                } else {
                    EmptyStateView()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.teal)
            Text("No meeting selected")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Text("Start a capture or select a past meeting.")
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.canvas)
    }
}
