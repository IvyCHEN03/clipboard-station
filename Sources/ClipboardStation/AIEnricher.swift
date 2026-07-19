import Foundation

struct AIEnrichment: Decodable {
    let title: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case tags
        case keywords
    }

    init(title: String, tags: [String]) {
        self.title = title
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        if let tags = try? container.decodeIfPresent([String].self, forKey: .tags) {
            self.tags = tags
        } else if let keywords = try? container.decodeIfPresent([String].self, forKey: .keywords) {
            self.tags = keywords
        } else if let tagString = try? container.decodeIfPresent(String.self, forKey: .tags) {
            self.tags = Self.splitTags(tagString)
        } else if let keywordString = try? container.decodeIfPresent(String.self, forKey: .keywords) {
            self.tags = Self.splitTags(keywordString)
        } else {
            self.tags = []
        }
    }

    private static func splitTags(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: ",，、\n "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum AIEnrichmentError: LocalizedError {
    case invalidConfiguration
    case httpStatus(Int, String)
    case emptyResponse
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "API Key、模型名或 Base URL 不完整"
        case let .httpStatus(status, message):
            if message.isEmpty {
                return "HTTP \(status)"
            }
            return "HTTP \(status)：\(message)"
        case .emptyResponse:
            return "接口没有返回内容"
        case let .invalidJSON(content):
            return "返回不是预期 JSON：\(content)"
        }
    }
}

struct AIEnricher {
    struct APIErrorResponse: Decodable {
        struct APIError: Decodable {
            let message: String?
            let type: String?
            let code: String?
        }
        let error: APIError?
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
                let reasoning_content: String?
            }
            let message: Message
            let text: String?
        }
        let choices: [Choice]
    }

    func enrich(text: String, baseURL: String, model: String, apiKey: String) async throws -> AIEnrichment {
        let content = try await complete(
            messages: [
                [
                    "role": "system",
                    "content": "你只返回严格 JSON，不要 markdown，不要解释。格式：{\"title\":\"不超过18个中文字符的标题\",\"tags\":[\"3到5个中文短标签\"]}"
                ],
                [
                    "role": "user",
                    "content": String(text.prefix(2200))
                ]
            ],
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: 0.1,
            maxTokens: 300
        )
        return parse(content: content)
    }

    func polish(text: String, baseURL: String, model: String, apiKey: String) async throws -> String {
        let content = try await complete(
            messages: [
                [
                    "role": "system",
                    "content": """
                    你是严谨的文字编辑。把用户提供的多个内容块整理成一段逻辑连贯、自然流畅的正文。
                    忠实保留原意和关键细节，不新增事实；去掉重复，补充必要的过渡和指代。
                    如果原文主要是英文，就保持英文；否则使用中文。
                    只返回润色后的正文，不要标题、说明、列表标记或 Markdown 代码块。
                    """
                ],
                [
                    "role": "user",
                    "content": String(text.prefix(12_000))
                ]
            ],
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: 0.25,
            maxTokens: 1_800
        )
        let polished = Self.cleanPolishedContent(content)
        guard !polished.isEmpty else {
            throw AIEnrichmentError.emptyResponse
        }
        return polished
    }

    static func cleanPolishedContent(_ content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            let lines = result.components(separatedBy: .newlines)
            if lines.count >= 2 {
                result = lines.dropFirst().joined(separator: "\n")
            }
            if result.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("```") {
                result = String(result.trimmingCharacters(in: .whitespacesAndNewlines).dropLast(3))
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func complete(
        messages: [[String: String]],
        baseURL: String,
        model: String,
        apiKey: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let url = chatCompletionsURL(from: baseURL), !model.isEmpty, !apiKey.isEmpty else {
            throw AIEnrichmentError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]
        if url.host?.localizedCaseInsensitiveContains("api.deepseek.com") == true,
           model.localizedCaseInsensitiveContains("v4") {
            body["thinking"] = ["type": "disabled"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIEnrichmentError.httpStatus(http.statusCode, message(from: data))
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content
            ?? decoded.choices.first?.text
            ?? decoded.choices.first?.message.reasoning_content
            ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIEnrichmentError.emptyResponse
        }
        return content
    }

    private func parse(content: String) -> AIEnrichment {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            json = String(trimmed[start...end])
        } else {
            json = trimmed
        }

        if let data = json.data(using: .utf8),
           let result = try? JSONDecoder().decode(AIEnrichment.self, from: data) {
            return AIEnrichment(
                title: String(result.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18)),
                tags: clean(result.tags)
            )
        }

        return fallbackEnrichment(from: trimmed)
    }

    private func message(from data: Data) -> String {
        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           let error = apiError.error {
            return [error.message, error.type, error.code]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
        }
        if let raw = String(data: data, encoding: .utf8) {
            return String(raw.prefix(180))
        }
        return ""
    }

    private func clean(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        let cleaned = tags.compactMap { tag -> String? in
            let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else {
                return nil
            }
            seen.insert(value)
            return String(value.prefix(10))
        }
        return Array(cleaned.prefix(5))
    }

    private func fallbackEnrichment(from content: String) -> AIEnrichment {
        let separators = CharacterSet(charactersIn: "\n,，、;；|#：:")
        let tokens = content
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let title = String((tokens.first ?? content).prefix(18))
        let tags = clean(Array(tokens.dropFirst()).isEmpty ? tokens : Array(tokens.dropFirst()))
        return AIEnrichment(title: title, tags: tags)
    }

    private func chatCompletionsURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme,
              scheme.hasPrefix("http"),
              let host = components.host else {
            return nil
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty || path == "v1" {
            components.path = "/chat/completions"
        } else if !path.hasSuffix("chat/completions") {
            if host.localizedCaseInsensitiveContains("api.deepseek.com")
                || host.localizedCaseInsensitiveContains("api.openai.com") {
                components.path = "/" + path + "/chat/completions"
            }
        }
        return components.url
    }
}
