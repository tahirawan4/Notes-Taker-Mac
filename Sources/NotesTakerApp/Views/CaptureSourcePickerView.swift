import SwiftUI

struct CaptureSourcePickerView: View {
    let meetingSource: MeetingSource
    let onSelect: (CaptureTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targets: [CaptureTarget] = [.mainDisplay()]
    @State private var selectedTargetID = CaptureTarget.mainDisplay().id
    @State private var errorMessage: String?
    @State private var isLoading = true

    private var selectedTarget: CaptureTarget {
        targets.first { $0.id == selectedTargetID } ?? .mainDisplay()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Capture Source")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text("Select the full screen or a specific window for this \(meetingSource.rawValue) meeting.")
                    .foregroundStyle(AppColors.textMuted)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading windows...")
                        .foregroundStyle(AppColors.textMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Capture sources unavailable", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.coral)
                    Text(errorMessage)
                        .foregroundStyle(AppColors.textMuted)
                    Text("Full Screen remains available after Screen Recording permission is active.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSoft)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(targets) { target in
                            Button {
                                selectedTargetID = target.id
                            } label: {
                                CaptureTargetRow(target: target, isSelected: selectedTargetID == target.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 300)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button {
                    onSelect(selectedTarget)
                    dismiss()
                } label: {
                    Label("Start Capture", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(isLoading)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(AppColors.canvas)
        .preferredColorScheme(.light)
        .task {
            await loadTargets()
        }
    }

    private func loadTargets() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await CaptureSourceProvider().availableTargets()
            targets = loaded.isEmpty ? [.mainDisplay()] : loaded
            selectedTargetID = targets.first?.id ?? CaptureTarget.mainDisplay().id
        } catch {
            targets = [.mainDisplay()]
            selectedTargetID = CaptureTarget.mainDisplay().id
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CaptureTargetRow: View {
    let target: CaptureTarget
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: target.kind == .display ? "display" : "macwindow")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .teal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(target.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : AppColors.text)
                Text(target.subtitle)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.78) : AppColors.textMuted)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(isSelected ? Color.softNavy : AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.teal.opacity(0.5) : Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}
