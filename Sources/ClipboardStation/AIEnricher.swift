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
    case inputTooLong(Int)

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
        case let .inputTooLong(limit):
            return "发送给 AI 的内容超过 \(limit) 字，请减少片段"
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

    func enrich(
        text: String,
        existingTags: [String] = [],
        baseURL: String,
        model: String,
        apiKey: String
    ) async throws -> AIEnrichment {
        let content = try await complete(
            messages: [
                [
                    "role": "system",
                    "content": Self.taggingSystemPrompt(existingTags: existingTags)
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
        let result = parse(content: content)
        return AIEnrichment(
            title: result.title,
            tags: Self.normalizedAITags(result.tags, existingTags: existingTags)
        )
    }

    func perform(
        action: AIActionType,
        context: String,
        instruction: String?,
        baseURL: String,
        model: String,
        apiKey: String
    ) async throws -> String {
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContext.count <= ContextPackageFormatter.maximumContextLength else {
            throw AIEnrichmentError.inputTooLong(ContextPackageFormatter.maximumContextLength)
        }
        let cleanInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userContent = cleanInstruction.isEmpty
            ? trimmedContext
            : "用户补充要求：\n\(cleanInstruction)\n\n\(trimmedContext)"
        let content = try await complete(
            messages: [
                [
                    "role": "system",
                    "content": Self.systemPrompt(for: action)
                ],
                [
                    "role": "user",
                    "content": userContent
                ]
            ],
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: 0.25,
            maxTokens: 1_800
        )
        let result = Self.cleanPolishedContent(content)
        guard !result.isEmpty else {
            throw AIEnrichmentError.emptyResponse
        }
        return result
    }

    func polish(text: String, baseURL: String, model: String, apiKey: String) async throws -> String {
        try await perform(
            action: .faithfulMerge,
            context: text,
            instruction: nil,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey
        )
    }

    static func taggingSystemPrompt(existingTags: [String]) -> String {
        let tags = TagNormalization.unique(existingTags)
        let existing = tags.isEmpty ? "无" : tags.joined(separator: "、")
        return """
        你只返回严格 JSON，不要 Markdown，不要解释。
        格式：{"title":"不超过18个中文字符的标题","tags":["最多3个标签"]}
        已有标签：\(existing)
        优先从已有标签中选择最多 3 个标签。
        只有确实没有适用标签时才创建新标签。
        不要创建与已有标签近义或仅表达形式不同的标签。
        标签使用 2–6 个中文字符或简短英文词组。
        """
    }

    static func normalizedAITags(_ tags: [String], existingTags: [String]) -> [String] {
        let existingByKey = Dictionary(
            TagNormalization.unique(existingTags).map {
                (TagNormalization.canonicalKey($0), $0)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let normalized = TagNormalization.unique(tags, maximumLength: 10).map { tag in
            existingByKey[TagNormalization.canonicalKey(tag)] ?? tag
        }
        return Array(TagNormalization.unique(normalized).prefix(3))
    }

    static func systemPrompt(for action: AIActionType) -> String {
        let common = """
        输入按 [片段 N] 保留了来源边界。不得虚构事实；必要时可以保留 [片段 N] 引用。
        如果原文主要是英文，就保持英文；否则使用中文。只返回结果正文。
        """
        switch action {
        case .faithfulMerge:
            return """
            你是严谨的内容编辑。忠实合并多个片段，保留数字、日期、名称和限定条件。
            去除重复，调整顺序和衔接，不新增上下文不存在的事实。
            不要把不同来源的观点错误合并成一个确定结论。
            \(common)
            """
        case .summarize:
            return """
            你是严谨的摘要编辑。提炼核心观点，同时保留重要事实、数字、日期、名称、限定条件和结论。
            删除重复与次要措辞，但不要牺牲影响判断的信息。
            \(common)
            """
        case .compare:
            return """
            你是研究分析编辑。明确区分不同片段的共同点、差异、冲突和信息缺口。
            不虚构比较维度；没有依据时明确说明未提供，而不是推断。
            \(common)
            """
        case .generatePrompt:
            return """
            你是提示词设计师。基于全部片段生成可直接使用的提示词。
            输出必须包含角色、任务、上下文、约束和输出格式，并保留关键事实与限定条件。
            \(common)
            """
        }
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
            guard let value = TagNormalization.normalized(tag, maximumLength: 10) else {
                return nil
            }
            let key = TagNormalization.canonicalKey(value)
            guard seen.insert(key).inserted else {
                return nil
            }
            return value
        }
        return Array(cleaned.prefix(3))
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
