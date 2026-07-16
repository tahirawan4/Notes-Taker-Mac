import Foundation

enum AINotesError: LocalizedError {
    case notConfigured
    case badResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "No AI provider is configured."
        case .badResponse:
            "The AI response could not be read."
        case .requestFailed(let detail):
            "AI notes failed: \(detail)"
        }
    }
}

struct AINotesResult: Codable {
    var summary: [String]
    var decisions: [String]
    var risks: [String]
    var openQuestions: [String]
    var actionItems: [AIActionItem]
}

struct AIActionItem: Codable {
    var owner: String?
    var task: String
    var priority: String?
}

struct AINotesService {
    func enhance(meeting: Meeting, transcript: String, settings: AISettingsSnapshot) async throws -> Meeting {
        guard settings.isAIEnabled else {
            throw AINotesError.notConfigured
        }

        let prompt = makePrompt(meeting: meeting, transcript: transcript)
        let jsonText: String
        switch settings.provider {
        case .local:
            throw AINotesError.notConfigured
        case .openAI:
            jsonText = try await callOpenAI(prompt: prompt, settings: settings)
        case .claude:
            jsonText = try await callClaude(prompt: prompt, settings: settings)
        case .gemini:
            jsonText = try await callGemini(prompt: prompt, settings: settings)
        }

        let result = try parseResult(from: jsonText)
        var enhanced = meeting
        enhanced.summary = result.summary
        enhanced.decisions = result.decisions
        enhanced.risks = result.risks
        enhanced.openQuestions = result.openQuestions
        enhanced.actionItems = result.actionItems.map {
            MeetingActionItem(
                owner: ($0.owner?.isEmpty == false ? $0.owner! : "Unassigned"),
                task: $0.task,
                dueDate: nil,
                priority: priority(from: $0.priority),
                status: .open,
                evidenceTimestamp: nil
            )
        }
        return enhanced
    }

    private func callOpenAI(prompt: String, settings: AISettingsSnapshot) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.openAIModel,
            "input": prompt,
            "temperature": 0.2
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try extractText(from: data)
    }

    private func callClaude(prompt: String, settings: AISettingsSnapshot) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(settings.claudeKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.claudeModel,
            "max_tokens": 1400,
            "temperature": 0.2,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try extractText(from: data)
    }

    private func callGemini(prompt: String, settings: AISettingsSnapshot) async throws -> String {
        let model = settings.geminiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedModel = (model.isEmpty ? "gemini-3.5-flash" : model)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "gemini-3.5-flash"
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(settings.geminiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": "application/json"
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try extractText(from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let detail = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw AINotesError.requestFailed(detail)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dict = object as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)
        }

        if let error = dict["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let status = error["status"] as? String, !status.isEmpty {
                return status
            }
        }

        return String(data: data, encoding: .utf8)
    }

    private func extractText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        if let text = findStringValue(in: object, keys: ["output_text", "text"]) {
            return text
        }
        throw AINotesError.badResponse
    }

    private func findStringValue(in object: Any, keys: Set<String>) -> String? {
        if let dict = object as? [String: Any] {
            for key in keys {
                if let value = dict[key] as? String, !value.isEmpty {
                    return value
                }
            }
            for value in dict.values {
                if let found = findStringValue(in: value, keys: keys) {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let found = findStringValue(in: value, keys: keys) {
                    return found
                }
            }
        }
        return nil
    }

    private func parseResult(from text: String) throws -> AINotesResult {
        let cleaned = stripCodeFence(text)
        guard let data = cleaned.data(using: .utf8) else {
            throw AINotesError.badResponse
        }
        return try JSONDecoder().decode(AINotesResult.self, from: data)
    }

    private func stripCodeFence(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value.replacingOccurrences(of: "```json", with: "")
            value = value.replacingOccurrences(of: "```", with: "")
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private func priority(from value: String?) -> ActionPriority {
        switch value?.lowercased() {
        case "high": .high
        case "low": .low
        default: .medium
        }
    }

    private func makePrompt(meeting: Meeting, transcript: String) -> String {
        """
        You are improving meeting notes for a macOS meeting notes app.
        Return ONLY valid JSON matching this schema:
        {
          "summary": ["short bullet"],
          "decisions": ["decision bullet"],
          "risks": ["risk or blocker bullet"],
          "openQuestions": ["question bullet"],
          "actionItems": [{"owner":"name or Unassigned","task":"clear action","priority":"Low|Medium|High"}]
        }

        Rules:
        - Be precise and professional.
        - Do not invent facts not supported by the transcript.
        - Keep bullets concise.
        - If there are no decisions, risks, questions, or action items, return empty arrays.

        Meeting title: \(meeting.title)
        Source: \(meeting.source.rawValue)
        Transcript:
        \(transcript)
        """
    }
}
