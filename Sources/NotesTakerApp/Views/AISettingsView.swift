import SwiftUI

struct AISettingsView: View {
    @Environment(AISettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Notes")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text("Optional. If no key is added, NotesTaker keeps using local transcription and basic notes.")
                    .foregroundStyle(AppColors.textMuted)
            }

            Picker("Provider", selection: $settings.provider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                if settings.provider == .openAI {
                    keySection(
                        title: "OpenAI API Key",
                        placeholder: "sk-...",
                        key: $settings.openAIKey,
                        modelTitle: "OpenAI Model",
                        model: $settings.openAIModel
                    )
                } else if settings.provider == .claude {
                    keySection(
                        title: "Claude API Key",
                        placeholder: "sk-ant-...",
                        key: $settings.claudeKey,
                        modelTitle: "Claude Model",
                        model: $settings.claudeModel
                    )
                } else {
                    Text("Local mode uses Apple Speech and built-in note extraction. No AI provider is called.")
                        .foregroundStyle(AppColors.textMuted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text("Keys are stored in macOS Keychain. Meeting transcript text is sent to the selected AI provider only when a key is configured and you click Process Recording.")
                .font(.caption)
                .foregroundStyle(AppColors.textMuted)

            HStack {
                Button("Clear Keys") {
                    settings.clearKeys()
                }
                .foregroundStyle(.coral)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                Button {
                    settings.save()
                    dismiss()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(AppColors.canvas)
        .preferredColorScheme(.light)
    }

    private func keySection(
        title: String,
        placeholder: String,
        key: Binding<String>,
        modelTitle: String,
        model: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            SecureField(placeholder, text: key)
                .textFieldStyle(.roundedBorder)
            Text(modelTitle)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            TextField("Model", text: model)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}
