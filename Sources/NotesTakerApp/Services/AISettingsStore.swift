import Foundation
import Observation

enum AIProvider: String, CaseIterable, Identifiable {
    case local = "Local"
    case openAI = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"

    var id: String { rawValue }
}

struct AISettingsSnapshot {
    var provider: AIProvider
    var openAIKey: String
    var claudeKey: String
    var geminiKey: String
    var openAIModel: String
    var claudeModel: String
    var geminiModel: String

    var isAIEnabled: Bool {
        switch provider {
        case .local:
            return false
        case .openAI:
            return !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .claude:
            return !claudeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gemini:
            return !geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

@Observable
final class AISettingsStore {
    private static let keychainService = "com.tahirawan.notestaker.ai"
    private static let providerKey = "ai.provider"
    private static let openAIModelKey = "ai.openai.model"
    private static let claudeModelKey = "ai.claude.model"
    private static let geminiModelKey = "ai.gemini.model"

    var provider: AIProvider
    var openAIKey: String
    var claudeKey: String
    var geminiKey: String
    var openAIModel: String
    var claudeModel: String
    var geminiModel: String

    init() {
        let defaults = UserDefaults.standard
        provider = AIProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "") ?? .local
        openAIModel = defaults.string(forKey: Self.openAIModelKey) ?? "gpt-4.1-mini"
        claudeModel = defaults.string(forKey: Self.claudeModelKey) ?? "claude-sonnet-4-20250514"
        geminiModel = Self.currentGeminiModel(from: defaults.string(forKey: Self.geminiModelKey))
        openAIKey = KeychainStore.read(service: Self.keychainService, account: "openai")
        claudeKey = KeychainStore.read(service: Self.keychainService, account: "claude")
        geminiKey = KeychainStore.read(service: Self.keychainService, account: "gemini")
    }

    var snapshot: AISettingsSnapshot {
        AISettingsSnapshot(
            provider: provider,
            openAIKey: openAIKey,
            claudeKey: claudeKey,
            geminiKey: geminiKey,
            openAIModel: openAIModel,
            claudeModel: claudeModel,
            geminiModel: geminiModel
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(openAIModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.openAIModelKey)
        defaults.set(claudeModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.claudeModelKey)
        defaults.set(geminiModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.geminiModelKey)
        KeychainStore.save(openAIKey, service: Self.keychainService, account: "openai")
        KeychainStore.save(claudeKey, service: Self.keychainService, account: "claude")
        KeychainStore.save(geminiKey, service: Self.keychainService, account: "gemini")
    }

    func clearKeys() {
        openAIKey = ""
        claudeKey = ""
        geminiKey = ""
        provider = .local
        save()
    }

    static func currentSnapshot() -> AISettingsSnapshot {
        AISettingsStore().snapshot
    }

    private static func currentGeminiModel(from storedValue: String?) -> String {
        let value = storedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty || value == "gemini-2.5-flash" {
            return "gemini-3.5-flash"
        }
        return value
    }
}
