import Foundation
import Observation

enum AIProvider: String, CaseIterable, Identifiable {
    case local = "Local"
    case openAI = "OpenAI"
    case claude = "Claude"

    var id: String { rawValue }
}

struct AISettingsSnapshot {
    var provider: AIProvider
    var openAIKey: String
    var claudeKey: String
    var openAIModel: String
    var claudeModel: String

    var isAIEnabled: Bool {
        switch provider {
        case .local:
            return false
        case .openAI:
            return !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .claude:
            return !claudeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

@Observable
final class AISettingsStore {
    private static let keychainService = "com.tahirawan.notestaker.ai"
    private static let providerKey = "ai.provider"
    private static let openAIModelKey = "ai.openai.model"
    private static let claudeModelKey = "ai.claude.model"

    var provider: AIProvider
    var openAIKey: String
    var claudeKey: String
    var openAIModel: String
    var claudeModel: String

    init() {
        let defaults = UserDefaults.standard
        provider = AIProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "") ?? .local
        openAIModel = defaults.string(forKey: Self.openAIModelKey) ?? "gpt-4.1-mini"
        claudeModel = defaults.string(forKey: Self.claudeModelKey) ?? "claude-sonnet-4-5"
        openAIKey = KeychainStore.read(service: Self.keychainService, account: "openai")
        claudeKey = KeychainStore.read(service: Self.keychainService, account: "claude")
    }

    var snapshot: AISettingsSnapshot {
        AISettingsSnapshot(
            provider: provider,
            openAIKey: openAIKey,
            claudeKey: claudeKey,
            openAIModel: openAIModel,
            claudeModel: claudeModel
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(openAIModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.openAIModelKey)
        defaults.set(claudeModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.claudeModelKey)
        KeychainStore.save(openAIKey, service: Self.keychainService, account: "openai")
        KeychainStore.save(claudeKey, service: Self.keychainService, account: "claude")
    }

    func clearKeys() {
        openAIKey = ""
        claudeKey = ""
        provider = .local
        save()
    }

    static func currentSnapshot() -> AISettingsSnapshot {
        AISettingsStore().snapshot
    }
}
