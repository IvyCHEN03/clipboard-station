import Carbon
import Foundation

enum SnippetSource: String, Codable, CaseIterable, Identifiable {
    case hotkeySelection
    case clipboardCopy
    case manualPasteboardImport
    case screenshot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hotkeySelection:
            return "快捷键拉取"
        case .clipboardCopy:
            return "复制监听"
        case .manualPasteboardImport:
            return "手动导入"
        case .screenshot:
            return "截图"
        }
    }
}

enum SnippetKind: String, Codable {
    case text
    case screenshot
    case spreadsheet
    case file

    var label: String {
        switch self {
        case .text:
            return "文字"
        case .screenshot:
            return "截图"
        case .spreadsheet:
            return "表格"
        case .file:
            return "文件"
        }
    }
}

struct Snippet: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var title: String
    var createdAt: Date
    var source: SnippetSource
    var kind: SnippetKind
    var attachmentPath: String?
    var fileName: String?
    var tags: [String]
    var isEnriching: Bool
    var enrichmentFailed: Bool
    var enrichmentError: String?

    var charCount: Int {
        text.count
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case title
        case createdAt
        case source
        case kind
        case attachmentPath
        case fileName
        case tags
        case isEnriching
        case enrichmentFailed
        case enrichmentError
    }

    init(
        id: UUID,
        text: String,
        title: String,
        createdAt: Date,
        source: SnippetSource,
        kind: SnippetKind = .text,
        attachmentPath: String? = nil,
        fileName: String? = nil,
        tags: [String] = [],
        isEnriching: Bool = false,
        enrichmentFailed: Bool = false,
        enrichmentError: String? = nil
    ) {
        self.id = id
        self.text = text
        self.title = title
        self.createdAt = createdAt
        self.source = source
        self.kind = kind
        self.attachmentPath = attachmentPath
        self.fileName = fileName
        self.tags = tags
        self.isEnriching = isEnriching
        self.enrichmentFailed = enrichmentFailed
        self.enrichmentError = enrichmentError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        source = try container.decode(SnippetSource.self, forKey: .source)
        kind = try container.decodeIfPresent(SnippetKind.self, forKey: .kind) ?? .text
        attachmentPath = try container.decodeIfPresent(String.self, forKey: .attachmentPath)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isEnriching = false
        enrichmentFailed = try container.decodeIfPresent(Bool.self, forKey: .enrichmentFailed) ?? false
        enrichmentError = try container.decodeIfPresent(String.self, forKey: .enrichmentError)
    }

    func matchesKeyword(_ keyword: String) -> Bool {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return true
        }
        return title.localizedCaseInsensitiveContains(value)
            || text.localizedCaseInsensitiveContains(value)
            || source.label.localizedCaseInsensitiveContains(value)
            || kind.label.localizedCaseInsensitiveContains(value)
            || tags.contains { tag in
                tag.localizedCaseInsensitiveContains(value)
                    || value.localizedCaseInsensitiveContains(tag)
            }
    }
}

struct DeletedSnippet: Identifiable, Codable, Equatable {
    var snippet: Snippet
    var deletedAt: Date

    var id: UUID { snippet.id }
}

struct StationSettings: Codable, Equatable {
    var monitorClipboard: Bool = true
    var autoPaste: Bool = true
    var launchAtLogin: Bool = false
    var persistSnippets: Bool = true
    var doubleSpacePopover: Bool = true
    var aiEnrichment: Bool = false
    var aiBaseURL: String = "https://api.openai.com/v1/chat/completions"
    var aiModel: String = "gpt-4o-mini"
    var hotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_C)
    var hotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    static let defaults = StationSettings()

    enum CodingKeys: String, CodingKey {
        case monitorClipboard
        case autoPaste
        case launchAtLogin
        case persistSnippets
        case doubleSpacePopover
        case aiEnrichment
        case aiBaseURL
        case aiModel
        case hotkeyKeyCode
        case hotkeyModifiers
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monitorClipboard = try container.decodeIfPresent(Bool.self, forKey: .monitorClipboard) ?? true
        autoPaste = try container.decodeIfPresent(Bool.self, forKey: .autoPaste) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        persistSnippets = try container.decodeIfPresent(Bool.self, forKey: .persistSnippets) ?? true
        doubleSpacePopover = try container.decodeIfPresent(Bool.self, forKey: .doubleSpacePopover) ?? true
        aiEnrichment = try container.decodeIfPresent(Bool.self, forKey: .aiEnrichment) ?? false
        aiBaseURL = try container.decodeIfPresent(String.self, forKey: .aiBaseURL) ?? "https://api.openai.com/v1/chat/completions"
        aiModel = try container.decodeIfPresent(String.self, forKey: .aiModel) ?? "gpt-4o-mini"
        hotkeyKeyCode = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyKeyCode) ?? UInt32(kVK_ANSI_C)
        hotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) ?? UInt32(cmdKey | shiftKey)
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct KeywordStat: Identifiable, Equatable {
    let tag: String
    let count: Int

    var id: String {
        tag
    }
}

enum TimeFilter: String, CaseIterable, Identifiable {
    case today
    case threeDays
    case fishMemory

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .today:
            return "今天"
        case .threeDays:
            return "3天"
        case .fishMemory:
            return "鱼的7天记忆"
        }
    }

    func contains(_ date: Date, now: Date = Date()) -> Bool {
        switch self {
        case .today:
            return Calendar.current.isDate(date, inSameDayAs: now)
        case .threeDays:
            return date >= Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        case .fishMemory:
            return date >= Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }
}
