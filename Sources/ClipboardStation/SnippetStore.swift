import AppKit
import Carbon
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SnippetStore: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var deletedSnippets: [DeletedSnippet] = []
    @Published var settings: StationSettings = .defaults {
        didSet {
            if oldValue != settings, didFinishInitialLoad, !isApplyingInitialLoad {
                persist()
                settingsChanged?(settings)
            }
        }
    }
    @Published var searchText = ""
    @Published var selectedTags = Set<String>()
    @Published var selectedTimeFilter: TimeFilter?
    @Published var selectedDateRange: DateRangeFilter?
    @Published var favoritesOnly = false
    @Published var toast: ToastMessage?
    @Published var draftExtraText = "" {
        didSet {
            if oldValue != draftExtraText {
                invalidatePolishedDraft()
            }
        }
    }
    @Published var draftTextSlots: [String: String] = [:] {
        didSet {
            if oldValue != draftTextSlots {
                invalidatePolishedDraft()
            }
        }
    }
    @Published var polishedDraftText = ""
    @Published var isPolishingDraft = false
    @Published var isPolishingQuickNote = false
    @Published var quickNoteText = "" {
        didSet {
            if oldValue != quickNoteText, didFinishInitialLoad, !isApplyingInitialLoad {
                persist()
            }
        }
    }
    @Published var aiAPIKey: String = "" {
        didSet {
            if oldValue != aiAPIKey, didFinishInitialLoad, !isApplyingInitialLoad {
                KeychainCredentials.save(aiAPIKey, account: "ai-api-key")
            }
        }
    }
    @Published var draftSnippetIDs: [UUID] = [] {
        didSet {
            if oldValue != draftSnippetIDs {
                invalidatePolishedDraft()
            }
        }
    }
    @Published var isAppRunning = true
    @Published var isShortcutListening = false
    @Published var shortcutStatusText = "未启动监听"
    @Published var isAccessibilityTrusted = false

    var settingsChanged: ((StationSettings) -> Void)?

    private let persistentStore = PersistentStore()
    private let enricher = AIEnricher()
    private let calendarReminderService = CalendarReminderService()
    private let attachmentsDirectory: URL
    private let isVideoDemo = ProcessInfo.processInfo.environment["CLIPBOARD_STATION_VIDEO_DEMO"] == "1"
    private var toastTask: Task<Void, Never>?
    private var didPromptForPasteAccessibility = false
    private var ignoredPasteboardChangeCounts = Set<Int>()
    private var fishMemoryTimer: AnyCancellable?
    private var videoDemoCommandTimer: AnyCancellable?
    private var lastVideoDemoCommand = ""
    private var polishedDraftSourceText = ""
    private var didFinishInitialLoad = false
    private var isApplyingInitialLoad = false
    private var pendingWebImageBatches: [String: PendingWebImageBatch] = [:]

    private struct PendingWebImageBatch {
        var images: [Int: CollectedWebImage]
        var expiresAt: Date
    }

    static let fishMemoryDuration: TimeInterval = 7 * 24 * 60 * 60

    var filteredSnippets: [Snippet] {
        SnippetFilter.apply(
            to: snippets,
            searchText: searchText,
            selectedTags: selectedTags,
            timeFilter: selectedTimeFilter,
            dateRange: selectedDateRange,
            favoritesOnly: favoritesOnly
        )
    }

    var draftSnippets: [Snippet] {
        draftSnippetIDs.compactMap { id in
            snippets.first { $0.id == id }
        }
    }

    var frequentTags: [KeywordStat] {
        Array(allTagStats.prefix(12))
    }

    var allTagStats: [KeywordStat] {
        var counts: [String: (label: String, count: Int)] = [:]
        for snippet in snippets {
            for tag in snippet.allTags {
                let key = TagNormalization.canonicalKey(tag)
                if let current = counts[key] {
                    counts[key] = (current.label, current.count + 1)
                } else {
                    counts[key] = (tag, 1)
                }
            }
        }
        return counts
            .map { KeywordStat(tag: $0.value.label, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    var customTagStats: [KeywordStat] {
        var counts: [String: (label: String, count: Int)] = [:]
        for snippet in snippets {
            for tag in TagNormalization.unique(
                snippet.customTags,
                maximumLength: TagNormalization.customTagMaximumLength
            ) {
                let key = TagNormalization.canonicalKey(tag)
                if let current = counts[key] {
                    counts[key] = (current.label, current.count + 1)
                } else {
                    counts[key] = (tag, 1)
                }
            }
        }
        return counts.values
            .map { KeywordStat(tag: $0.label, count: $0.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    var pendingTagCount: Int {
        snippets.filter { snippet in
            snippet.tags.isEmpty
                && !snippet.isEnriching
                && !snippet.enrichmentFailed
                && hasPotentialEnrichmentText(snippet)
        }.count
    }

    var runningTagCount: Int {
        snippets.filter(\.isEnriching).count
    }

    var failedTagCount: Int {
        snippets.filter(\.enrichmentFailed).count
    }

    var fishMemoryProgress: Double {
        guard let oldest = snippets.map(\.createdAt).min() else { return 0 }
        return Self.memoryProgress(createdAt: oldest)
    }

    var expiringSoonCount: Int {
        let warningDate = Date().addingTimeInterval(-6 * 24 * 60 * 60)
        return snippets.filter { $0.createdAt <= warningDate }.count
    }

    var fishMemoryStatusText: String {
        guard let oldest = snippets.map(\.createdAt).min() else {
            return "还没有需要整理的记忆"
        }
        let remaining = max(Self.fishMemoryDuration - Date().timeIntervalSince(oldest), 0)
        let hours = max(Int(ceil(remaining / 3600)), 1)
        if hours < 24 {
            return "最早一条约 \(hours) 小时后进入回忆浅滩"
        }
        return "最早一条约 \(Int(ceil(Double(hours) / 24))) 天后进入回忆浅滩"
    }

    func timeBucketCount(_ filter: TimeFilter, now: Date = Date()) -> Int {
        snippets.filter { filter.contains($0.createdAt, now: now) }.count
    }

    func timeBucketPercentage(_ filter: TimeFilter, now: Date = Date()) -> Int {
        guard !snippets.isEmpty else { return 0 }
        return Int((Double(timeBucketCount(filter, now: now)) / Double(snippets.count) * 100).rounded())
    }

    func displayIndex(for snippet: Snippet) -> Int? {
        snippets.firstIndex { $0.id == snippet.id }.map { $0 + 1 }
    }

    static func memoryProgress(createdAt: Date, now: Date = Date()) -> Double {
        min(max(now.timeIntervalSince(createdAt) / fishMemoryDuration, 0), 1)
    }

    static func shouldMoveToMemoryShore(createdAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) >= fishMemoryDuration
    }

    func toggleTagFilter(_ tag: String) {
        if let selected = selectedTags.first(where: {
            TagNormalization.canonicalKey($0) == TagNormalization.canonicalKey(tag)
        }) {
            selectedTags.remove(selected)
        } else {
            selectedTags.insert(tag)
        }
    }

    func isTagFilterSelected(_ tag: String) -> Bool {
        selectedTags.contains {
            TagNormalization.canonicalKey($0) == TagNormalization.canonicalKey(tag)
        }
    }

    @discardableResult
    func addCustomTag(_ rawTag: String, to ids: Set<UUID>) -> Bool {
        guard let tag = TagNormalization.normalized(
            rawTag,
            maximumLength: TagNormalization.customTagMaximumLength
        ), !ids.isEmpty else {
            showToast("标签不能为空，且最多 10 个字符")
            return false
        }
        var changedCount = 0
        for index in snippets.indices where ids.contains(snippets[index].id) {
            let existingKeys = Set(snippets[index].allTags.map(TagNormalization.canonicalKey))
            guard !existingKeys.contains(TagNormalization.canonicalKey(tag)) else {
                continue
            }
            snippets[index].customTags.append(tag)
            snippets[index].customTags = TagNormalization.unique(
                snippets[index].customTags,
                maximumLength: TagNormalization.customTagMaximumLength
            )
            changedCount += 1
        }
        guard changedCount > 0 else {
            showToast("所选内容已拥有这个标签")
            return false
        }
        persist()
        showToast("已为 \(changedCount) 条添加标签“\(tag)”")
        return true
    }

    func removeCustomTag(_ tag: String, from id: UUID) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            return
        }
        let key = TagNormalization.canonicalKey(tag)
        let oldCount = snippets[index].customTags.count
        snippets[index].customTags.removeAll { TagNormalization.canonicalKey($0) == key }
        guard snippets[index].customTags.count != oldCount else {
            return
        }
        persist()
    }

    @discardableResult
    func renameCustomTag(_ oldTag: String, to rawNewTag: String) -> Bool {
        guard let newTag = TagNormalization.normalized(
            rawNewTag,
            maximumLength: TagNormalization.customTagMaximumLength
        ) else {
            showToast("标签不能为空，且最多 10 个字符")
            return false
        }
        let oldKey = TagNormalization.canonicalKey(oldTag)
        var changed = false
        for index in snippets.indices {
            guard snippets[index].customTags.contains(where: {
                TagNormalization.canonicalKey($0) == oldKey
            }) else {
                continue
            }
            snippets[index].customTags = snippets[index].customTags.map {
                TagNormalization.canonicalKey($0) == oldKey ? newTag : $0
            }
            snippets[index].customTags = TagNormalization.unique(
                snippets[index].customTags,
                maximumLength: TagNormalization.customTagMaximumLength
            )
            changed = true
        }
        guard changed else {
            return false
        }
        replaceSelectedTag(oldTag, with: newTag)
        persist()
        showToast("已将“\(oldTag)”重命名为“\(newTag)”")
        return true
    }

    func deleteCustomTag(_ tag: String) {
        let key = TagNormalization.canonicalKey(tag)
        var changed = false
        for index in snippets.indices {
            let oldCount = snippets[index].customTags.count
            snippets[index].customTags.removeAll { TagNormalization.canonicalKey($0) == key }
            changed = changed || snippets[index].customTags.count != oldCount
        }
        guard changed else {
            return
        }
        selectedTags = Set(selectedTags.filter { TagNormalization.canonicalKey($0) != key })
        persist()
        showToast("已删除自定义标签“\(tag)”")
    }

    func isCustomTag(_ tag: String, on snippet: Snippet) -> Bool {
        let key = TagNormalization.canonicalKey(tag)
        return snippet.customTags.contains { TagNormalization.canonicalKey($0) == key }
    }

    func cleanupCustomTags() {
        let changed = normalizeCustomTagsInPlace()
        guard changed else {
            return
        }
        persist()
    }

    @discardableResult
    private func normalizeCustomTagsInPlace() -> Bool {
        var changed = false
        for index in snippets.indices {
            let normalized = TagNormalization.unique(
                snippets[index].customTags,
                maximumLength: TagNormalization.customTagMaximumLength
            )
            if normalized != snippets[index].customTags {
                snippets[index].customTags = normalized
                changed = true
            }
        }
        return changed
    }

    private func replaceSelectedTag(_ oldTag: String, with newTag: String) {
        let key = TagNormalization.canonicalKey(oldTag)
        guard selectedTags.contains(where: { TagNormalization.canonicalKey($0) == key }) else {
            return
        }
        selectedTags = Set(selectedTags.filter { TagNormalization.canonicalKey($0) != key })
        selectedTags.insert(newTag)
    }

    init(testingSnippets: [Snippet]? = nil) {
        if let testingSnippets {
            attachmentsDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClipboardStationTests-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("Attachments", isDirectory: true)
            try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            settings.monitorClipboard = false
            settings.autoPaste = false
            settings.persistSnippets = false
            settings.aiEnrichment = false
            snippets = testingSnippets
            didFinishInitialLoad = true
            return
        }
        if isVideoDemo {
            attachmentsDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClipboardStationVideoDemo", isDirectory: true)
                .appendingPathComponent("Attachments", isDirectory: true)
            try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            settings.monitorClipboard = false
            settings.autoPaste = false
            settings.persistSnippets = false
            settings.launchAtLogin = false
            settings.aiEnrichment = false
            snippets = DemoContent.makeSnippets()
            didFinishInitialLoad = true
            refreshRuntimeStatus(shortcutListening: false, detail: "视频演示模式")
            videoDemoCommandTimer = Timer.publish(every: 0.2, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.pollVideoDemoCommand()
                }
            return
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        attachmentsDirectory = base
            .appendingPathComponent("ClipboardStation", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        fishMemoryTimer = Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.expireFishMemory()
            }
        refreshRuntimeStatus(shortcutListening: false)
        loadPersistedStateInBackground()
    }

    private func loadPersistedStateInBackground() {
        let persistentStore = persistentStore
        Task.detached(priority: .userInitiated) { [weak self] in
            let state = persistentStore.loadIfAvailable()
            let apiKey = KeychainCredentials.read(account: "ai-api-key")
            await self?.finishInitialLoad(state: state, apiKey: apiKey)
        }
    }

    private func finishInitialLoad(state: PersistedState?, apiKey: String) {
        guard let state else {
            showToast("本地资料尚未解锁；允许钥匙串访问后请重启 App")
            return
        }

        isApplyingInitialLoad = true
        snippets = state.snippets.sorted { $0.createdAt > $1.createdAt }
        normalizeCustomTagsInPlace()
        deletedSnippets = state.deletedSnippets.sorted { $0.deletedAt > $1.deletedAt }
        settings = state.settings
        quickNoteText = state.quickNoteText
        aiAPIKey = apiKey
        isApplyingInitialLoad = false
        didFinishInitialLoad = true

        repairShortcutIfNeeded()
        repairDeepSeekSettingsIfNeeded()
        expireFishMemory()
        settingsChanged?(settings)
    }

    func add(text rawText: String, source: SnippetSource, force: Bool = false) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast("没有可收集的文本")
            return
        }

        let snippet = Snippet(
            id: UUID(),
            text: text,
            title: Self.makeTitle(from: text),
            createdAt: Date(),
            source: source
        )
        snippets.insert(snippet, at: 0)
        persist()
        showToast("已收集 \(snippet.charCount) 字")
        enrichSnippetIfNeeded(snippet.id)
    }

    func saveQuickNote() {
        let note = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else {
            showToast("随笔还是空的")
            return
        }
        add(text: note, source: .quickNote, force: true)
        quickNoteText = ""
        showToast("随笔已形成一条内容")
    }

    func polishQuickNote() {
        let source = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            showToast("随笔没有可润色的文字")
            return
        }
        guard let configuration = polishConfiguration() else { return }
        guard !isPolishingQuickNote else { return }

        isPolishingQuickNote = true
        showToast("AI 正在整理随笔")
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await enricher.polish(
                    text: source,
                    baseURL: configuration.baseURL,
                    model: configuration.model,
                    apiKey: configuration.apiKey
                )
                guard quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines) == source else {
                    isPolishingQuickNote = false
                    showToast("随笔内容已变化，未覆盖新的文字")
                    return
                }
                quickNoteText = result
                isPolishingQuickNote = false
                showToast("随笔 AI 整理完成")
            } catch {
                isPolishingQuickNote = false
                handleAIError(error, prefix: "随笔 AI 整理失败")
            }
        }
    }

    func toggleRepresentation(for snippet: Snippet) {
        guard snippet.supportsRepresentationToggle,
              let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }
        if snippet.effectiveRepresentation == .image {
            if snippet.kind == .screenshot, screenshotText(for: snippet)?.isEmpty != false {
                showToast("这张图片没有识别到文字")
                return
            }
            snippets[index].representation = .text
            showToast("已切换为文字")
        } else {
            snippets[index].representation = .image
            showToast("已切换为图片")
        }
        persist()
    }

    func addCalendarEvent(for snippet: Snippet) {
        guard let detected = detectedDate(for: snippet) else {
            showToast("这条内容里没有识别到日期时间")
            return
        }
        let service = calendarReminderService
        Task { @MainActor [weak self] in
            do {
                try await service.addEvent(title: snippet.title, notes: snippet.text, date: detected.date)
                self?.showToast("已加入日历")
            } catch {
                self?.showToast("加入日历失败：\(Self.shortError(error))")
            }
        }
    }

    func toggleFavorite(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }
        snippets[index].isFavorite.toggle()
        persist()
        showToast(snippets[index].isFavorite ? "已收藏，7 天后也会保留" : "已取消收藏")
    }

    func addAlarmReminder(for snippet: Snippet) {
        guard let detected = detectedDate(for: snippet) else {
            showToast("这条内容里没有识别到日期时间")
            return
        }
        let service = calendarReminderService
        Task { @MainActor [weak self] in
            do {
                try await service.addReminder(title: snippet.title, notes: snippet.text, date: detected.date)
                self?.showToast("已创建闹钟提醒")
            } catch {
                self?.showToast("创建提醒失败：\(Self.shortError(error))")
            }
        }
    }

    func detectedDate(for snippet: Snippet) -> DetectedDateContent? {
        DateContentDetector.firstDate(in: snippet.text)
    }

    func addSpreadsheetText(_ rawText: String, source: SnippetSource) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast("没有可收集的表格")
            return
        }
        let fileName = "table-\(Self.fileDateFormatter.string(from: Date())).tsv"
        let url = attachmentsDirectory.appendingPathComponent(fileName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showToast("表格文件保存失败")
            return
        }
        let snippet = Snippet(
            id: UUID(),
            text: text,
            title: "表格片段",
            createdAt: Date(),
            source: source,
            kind: .spreadsheet,
            attachmentPath: url.path,
            fileName: fileName
        )
        snippets.insert(snippet, at: 0)
        persist()
        showToast("已保存表格片段")
        enrichSnippetIfNeeded(snippet.id)
    }

    func addAttachmentFile(from sourceURL: URL, kind: SnippetKind, source: SnippetSource) {
        guard let savedURL = copyAttachment(from: sourceURL) else {
            showToast("附件保存失败")
            return
        }
        let fileName = sourceURL.lastPathComponent
        let text = kind == .screenshot
            ? (Self.recognizedText(from: savedURL) ?? "")
            : savedURL.path
        let snippet = Snippet(
            id: UUID(),
            text: text,
            title: titleForAttachment(fileName: fileName, kind: kind),
            createdAt: Date(),
            source: source,
            kind: kind,
            attachmentPath: savedURL.path,
            fileName: fileName
        )
        snippets.insert(snippet, at: 0)
        persist()
        showToast(kind == .screenshot ? "已保存截图" : "已保存文件")
    }

    func addImageFromPasteboard(_ pasteboard: NSPasteboard, source: SnippetSource) -> Bool {
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        let fileName = "screenshot-\(Self.fileDateFormatter.string(from: Date())).png"
        let url = attachmentsDirectory.appendingPathComponent(fileName)
        do {
            try png.write(to: url, options: [.atomic])
            let snippet = Snippet(
                id: UUID(),
                text: Self.recognizedText(from: url) ?? "",
                title: "截图 \(Self.displayDateFormatter.string(from: Date()))",
                createdAt: Date(),
                source: source,
                kind: .screenshot,
                attachmentPath: url.path,
                fileName: fileName
            )
            snippets.insert(snippet, at: 0)
            persist()
            showToast("已保存截图")
            return true
        } catch {
            showToast("截图保存失败")
            return false
        }
    }

    @discardableResult
    func addWebImage(_ image: CollectedWebImage) -> Bool {
        guard NSImage(data: image.data) != nil else {
            showToast("网页图片格式无效")
            return false
        }
        let now = Date()
        pendingWebImageBatches = pendingWebImageBatches.filter { $0.value.expiresAt > now }
        let total = min(max(image.total, 1), 100)
        var batch = pendingWebImageBatches[image.batchID]
            ?? PendingWebImageBatch(images: [:], expiresAt: now.addingTimeInterval(120))
        batch.images[image.index] = image
        batch.expiresAt = now.addingTimeInterval(120)
        pendingWebImageBatches[image.batchID] = batch

        guard batch.images.count >= total else {
            return true
        }
        pendingWebImageBatches.removeValue(forKey: image.batchID)
        let ordered = batch.images.values.sorted { $0.index < $1.index }
        return saveWebImageBatch(Array(ordered.prefix(total)))
    }

    private func saveWebImageBatch(_ images: [CollectedWebImage]) -> Bool {
        guard !images.isEmpty else { return false }
        let stamp = Self.fileDateFormatter.string(from: Date())
        var paths: [String] = []
        var fileNames: [String] = []
        for image in images {
            let fileName = "web-image-\(stamp)-\(image.index)-\(UUID().uuidString.prefix(8)).png"
            let url = attachmentsDirectory.appendingPathComponent(fileName)
            do {
                try image.data.write(to: url, options: [.atomic])
                paths.append(url.path)
                fileNames.append(fileName)
            } catch {
                paths.forEach { try? FileManager.default.removeItem(atPath: $0) }
                showToast("网页图片组保存失败")
                return false
            }
        }

        let cleanTitle = images[0].title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = images
            .map { $0.ocrText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let snippet = Snippet(
            id: UUID(),
            text: cleanText,
            title: cleanTitle.isEmpty ? "网页图片组" : cleanTitle,
            createdAt: Date(),
            source: .webImageCollector,
            kind: .screenshot,
            attachmentPath: paths.first,
            fileName: fileNames.first,
            attachmentPaths: paths,
            attachmentFileNames: fileNames,
            representation: .image
        )
        snippets.insert(snippet, at: 0)
        persist()
        enrichSnippetIfNeeded(snippet.id)
        showToast(cleanText.isEmpty
            ? "\(images.count) 张图片已存入同一个灵感框"
            : "\(images.count) 张图片和 OCR 文字已存入同一个灵感框")
        return true
    }

    func addPasteboardContents(source: SnippetSource) {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let handled = importSupportedURLs(urls, source: source), handled {
            return
        }
        if addImageFromPasteboard(pasteboard, source: source) {
            return
        }
        guard let text = pasteboard.string(forType: .string) else {
            showToast("剪贴板没有可保存内容")
            return
        }
        if PasteboardContentClassifier.looksLikeSpreadsheet(text) {
            addSpreadsheetText(text, source: source)
        } else {
            add(text: text, source: source, force: true)
        }
    }

    func updateTitle(for snippet: Snippet, title: String) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }
        snippets[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if snippets[index].title.isEmpty {
            snippets[index].title = Self.makeTitle(from: snippets[index].text)
        }
        if draftSnippetIDs.contains(snippet.id) {
            invalidatePolishedDraft()
        }
        persist()
    }

    func delete(_ snippet: Snippet) {
        moveToMemoryShore([snippet])
        draftSnippetIDs.removeAll { $0 == snippet.id }
        persist()
        showToast("已移到回忆浅滩")
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else {
            return
        }
        let removed = snippets.filter { ids.contains($0.id) }
        moveToMemoryShore(removed)
        draftSnippetIDs.removeAll { ids.contains($0) }
        persist()
        showToast("已将 \(ids.count) 条移到回忆浅滩")
    }

    func restoreFromMemoryShore(_ item: DeletedSnippet) {
        guard let index = deletedSnippets.firstIndex(where: { $0.id == item.id }) else { return }
        var restored = deletedSnippets.remove(at: index).snippet
        restored.isFavorite = true
        snippets.insert(restored, at: 0)
        persist()
        showToast("已找回并收藏“\(restored.title)”")
    }

    func restoreAllFromMemoryShore() {
        var state = PersistedState(
            snippets: snippets,
            deletedSnippets: deletedSnippets,
            settings: settings,
            quickNoteText: quickNoteText
        )
        let restoredCount = state.restoreAllDeletedAsFavorites()
        guard restoredCount > 0 else { return }
        snippets = state.snippets
        deletedSnippets = state.deletedSnippets
        persist()
        showToast("已找回并收藏 \(restoredCount) 条历史资料")
    }

    func permanentlyDelete(_ item: DeletedSnippet) {
        guard let index = deletedSnippets.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = deletedSnippets.remove(at: index).snippet
        AttachmentCleanup.removeAttachments(for: [removed], in: attachmentsDirectory)
        persist()
        showToast("已永久删除")
    }

    func emptyMemoryShore() {
        AttachmentCleanup.removeAttachments(for: deletedSnippets.map(\.snippet), in: attachmentsDirectory)
        deletedSnippets.removeAll()
        persist()
        showToast("回忆浅滩已清空")
    }

    func moveSnippet(id: UUID, before targetID: UUID?) {
        guard let from = snippets.firstIndex(where: { $0.id == id }) else {
            return
        }
        let item = snippets.remove(at: from)

        if let targetID, let target = snippets.firstIndex(where: { $0.id == targetID }) {
            snippets.insert(item, at: target)
        } else {
            snippets.append(item)
        }
        persist()
    }

    func moveSnippetUp(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }), index > 0 else {
            return
        }
        snippets.swapAt(index, index - 1)
        persist()
    }

    func moveSnippetDown(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }), index < snippets.count - 1 else {
            return
        }
        snippets.swapAt(index, index + 1)
        persist()
    }

    func moveSnippet(_ snippet: Snippet, toDisplayIndex displayIndex: Int) {
        guard let from = snippets.firstIndex(where: { $0.id == snippet.id }) else {
            return
        }
        let bounded = min(max(displayIndex, 1), snippets.count)
        let item = snippets.remove(at: from)
        snippets.insert(item, at: bounded - 1)
        persist()
    }

    @discardableResult
    func addToDraft(id: UUID, before targetID: UUID? = nil) -> DraftAdditionResult {
        addToDraft(idsInDisplayOrder: [id], before: targetID)
    }

    @discardableResult
    func addToDraft(
        idsInDisplayOrder ids: [UUID],
        before targetID: UUID? = nil,
        showFeedback: Bool = true
    ) -> DraftAdditionResult {
        let orderedIDs = ids.reduce(into: [UUID]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        var existing = Set(draftSnippetIDs)
        var additions: [UUID] = []
        var duplicateCount = 0
        var unavailableCount = 0
        var changedRepresentation = false

        for id in orderedIDs {
            guard let index = snippets.firstIndex(where: { $0.id == id }) else {
                unavailableCount += 1
                continue
            }
            guard !existing.contains(id) else {
                duplicateCount += 1
                continue
            }
            let snippet = snippets[index]
            if snippet.kind == .screenshot {
                guard screenshotText(for: snippet)?.isEmpty == false else {
                    unavailableCount += 1
                    continue
                }
                if snippets[index].effectiveRepresentation != .text {
                    snippets[index].representation = .text
                    changedRepresentation = true
                }
            }
            additions.append(id)
            existing.insert(id)
        }

        if !additions.isEmpty {
            let insertionIndex = targetID
                .flatMap { draftSnippetIDs.firstIndex(of: $0) }
                ?? draftSnippetIDs.endIndex
            draftSnippetIDs.insert(contentsOf: additions, at: insertionIndex)
        }
        if changedRepresentation {
            persist()
        }

        let result = DraftAdditionResult(
            addedCount: additions.count,
            duplicateCount: duplicateCount,
            unavailableCount: unavailableCount
        )
        if showFeedback {
            showDraftAdditionFeedback(result)
        }
        return result
    }

    private func showDraftAdditionFeedback(_ result: DraftAdditionResult) {
        if result.addedCount > 0 {
            var message = "已加入 \(result.addedCount) 条"
            if result.duplicateCount > 0 {
                message += "，跳过 \(result.duplicateCount) 条重复内容"
            }
            if result.unavailableCount > 0 {
                message += "，\(result.unavailableCount) 条没有可用文字"
            }
            showToast(message)
        } else if result.duplicateCount > 0, result.unavailableCount == 0 {
            showToast("所选内容已在组合框中")
        } else if result.unavailableCount > 0 {
            showToast("所选图片没有可用于组合的 OCR 文字")
        }
    }

    func moveDraftBlock(id: UUID, before targetID: UUID?) {
        guard let from = draftSnippetIDs.firstIndex(of: id) else {
            addToDraft(id: id, before: targetID)
            return
        }
        let item = draftSnippetIDs.remove(at: from)
        if let targetID, let targetIndex = draftSnippetIDs.firstIndex(of: targetID) {
            draftSnippetIDs.insert(item, at: targetIndex)
        } else {
            draftSnippetIDs.append(item)
        }
    }

    func removeDraftBlock(id: UUID) {
        draftSnippetIDs.removeAll { $0 == id }
        draftTextSlots.removeValue(forKey: draftSlotKey(before: id))
    }

    func clearDraft() {
        draftSnippetIDs.removeAll()
        draftTextSlots.removeAll()
        draftExtraText = ""
        showToast("已取消组合框全部内容")
    }

    func copyDraftText() {
        copyDraftOutput()
    }

    func copyDraftOutput(_ format: DraftOutputFormat? = nil) {
        let text: String?
        if format == .fullContext {
            do {
                text = try currentDraftContext()
            } catch {
                showToast(error.localizedDescription)
                return
            }
        } else {
            text = draftOutput(format: format)
        }
        guard let text, !text.isEmpty else {
            showToast("组合框没有可复制内容")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        markInternalPasteboardWrite()
        if let format {
            showToast("已\(format.label)")
        } else {
            showToast(hasCurrentPolishedDraft ? "已复制 AI 整理结果" : "已复制组合框原文")
        }
    }

    func pasteDraftOutput() {
        guard draftOutput(format: nil)?.isEmpty == false else {
            showToast("组合框没有可复制内容")
            return
        }
        let shouldPrompt = !didPromptForPasteAccessibility
        didPromptForPasteAccessibility = true
        guard AccessibilityService.isTrusted(prompt: shouldPrompt) else {
            showToast("需要开启辅助功能权限才能粘贴到前台应用")
            return
        }
        copyDraftOutput()
        NSApp.keyWindow?.orderOut(nil)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            AccessibilityService.sendCommandV()
            self?.showToast("已粘贴到前台应用")
        }
    }

    func draftOutput(format: DraftOutputFormat?) -> String? {
        let assembled = assembledDraftText()
        guard !assembled.isEmpty else {
            return nil
        }
        let validResult = hasCurrentPolishedDraft
            ? polishedDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        switch format {
        case .none:
            return validResult.map(ContextPackageFormatter.cleanBody) ?? assembled
        case .cleanBody:
            return ContextPackageFormatter.cleanBody(validResult ?? assembled)
        case .withSources:
            return ContextPackageFormatter.resultWithSources(
                validResult ?? assembled,
                snippets: draftSnippets
            )
        case .fullContext:
            return try? currentDraftContext()
        }
    }

    func setAIAction(_ action: AIActionType) {
        guard settings.aiActionType != action else {
            return
        }
        settings.aiActionType = action
        invalidatePolishedDraft()
    }

    func polishDraft() {
        performDraftAI()
    }

    func performDraftAI() {
        guard !draftSnippets.isEmpty else {
            showToast("组合框没有可整理的片段")
            return
        }
        let context: String
        do {
            context = try currentDraftContext()
        } catch {
            showToast(error.localizedDescription)
            return
        }
        guard !context.isEmpty else {
            showToast("组合框没有可整理的文字")
            return
        }
        guard let configuration = polishConfiguration() else { return }
        guard !isPolishingDraft else { return }

        let action = settings.aiActionType
        let fingerprint = draftFingerprint(context: context, action: action)
        isPolishingDraft = true
        showToast("AI 正在整理")
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await enricher.perform(
                    action: action,
                    context: context,
                    instruction: nil,
                    baseURL: configuration.baseURL,
                    model: configuration.model,
                    apiKey: configuration.apiKey
                )
                guard currentDraftFingerprint() == fingerprint else {
                    isPolishingDraft = false
                    showToast("组合内容已变化，请重新整理")
                    return
                }
                acceptAIResult(result, fingerprint: fingerprint)
                isPolishingDraft = false
                showToast("AI 整理完成")
            } catch {
                isPolishingDraft = false
                handleAIError(error, prefix: "AI 整理失败")
            }
        }
    }

    var hasCurrentPolishedDraft: Bool {
        !polishedDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && polishedDraftSourceText == currentDraftFingerprint()
    }

    private func polishConfiguration() -> (baseURL: String, model: String, apiKey: String)? {
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = settings.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty, !baseURL.isEmpty else {
            showToast("请先在设置中填写 AI API Key、模型名和 Base URL")
            return nil
        }
        return (baseURL, model, key)
    }

    private func assembledDraftText() -> String {
        var parts: [String] = []
        for snippet in draftSnippets {
            if let before = draftSlotText(before: snippet.id), !before.isEmpty {
                parts.append(before)
            }
            if let text = exportText(for: snippet), !text.isEmpty {
                parts.append(text)
            }
        }
        if let after = draftSlotTextAfterAll(), !after.isEmpty {
            parts.append(after)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func currentDraftContext() throws -> String {
        let snippets = draftSnippets
        return try ContextPackageFormatter.fullContext(
            snippets: snippets,
            instruction: draftExtraText
        ) { [weak self] snippet in
            guard let self else {
                return nil
            }
            var parts: [String] = []
            if let before = draftSlotText(before: snippet.id), !before.isEmpty {
                parts.append(before)
            }
            if let text = exportText(for: snippet), !text.isEmpty {
                parts.append(text)
            }
            if snippet.id == snippets.last?.id,
               let after = draftSlotTextAfterAll(),
               !after.isEmpty {
                parts.append(after)
            }
            return parts.joined(separator: "\n\n")
        }
    }

    private func currentDraftFingerprint() -> String {
        guard let context = try? currentDraftContext() else {
            return ""
        }
        return draftFingerprint(context: context, action: settings.aiActionType)
    }

    private func draftFingerprint(context: String, action: AIActionType) -> String {
        "\(action.rawValue)\n\(context)"
    }

    func acceptAIResult(_ result: String, fingerprint: String? = nil) {
        polishedDraftSourceText = fingerprint ?? currentDraftFingerprint()
        polishedDraftText = result
    }

    private func invalidatePolishedDraft() {
        polishedDraftText = ""
        polishedDraftSourceText = ""
    }

    func bindingForDraftSlot(before id: UUID) -> Binding<String> {
        Binding(
            get: { self.draftTextSlots[self.draftSlotKey(before: id)] ?? "" },
            set: { self.draftTextSlots[self.draftSlotKey(before: id)] = $0 }
        )
    }

    func bindingForDraftSlotAfterAll() -> Binding<String> {
        Binding(
            get: { self.draftTextSlots[self.draftSlotAfterAllKey] ?? "" },
            set: { self.draftTextSlots[self.draftSlotAfterAllKey] = $0 }
        )
    }

    func clear() {
        moveToMemoryShore(snippets)
        snippets.removeAll()
        draftSnippetIDs.removeAll()
        draftTextSlots.removeAll()
        draftExtraText = ""
        persist()
        showToast("全部内容已移到回忆浅滩")
    }

    func clearLocalData() {
        AttachmentCleanup.removeAttachments(
            for: snippets + deletedSnippets.map(\.snippet),
            in: attachmentsDirectory
        )
        snippets.removeAll()
        deletedSnippets.removeAll()
        draftSnippetIDs.removeAll()
        draftTextSlots.removeAll()
        draftExtraText = ""
        try? FileManager.default.removeItem(at: attachmentsDirectory)
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        persist()
        showToast("已清除本地片段和附件")
    }

    func testAIConnection() {
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = settings.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty, !baseURL.isEmpty else {
            showToast("请先填写 API Key、模型名和 Base URL")
            return
        }
        showToast("正在测试 AI")
        Task { [weak self] in
            do {
                let result = try await self?.enricher.enrich(
                    text: "测试连接：请返回标题和标签。",
                    baseURL: baseURL,
                    model: model,
                    apiKey: key
                )
                await MainActor.run {
                    if result != nil {
                        self?.showToast("AI 连接成功")
                    } else {
                        self?.showToast("AI 已响应，但返回格式异常")
                    }
                }
            } catch {
                await MainActor.run {
                    self?.handleAIError(error, prefix: "AI 连接失败")
                }
            }
        }
    }

    func refreshRuntimeStatus(shortcutListening: Bool, detail: String? = nil) {
        isAppRunning = true
        isShortcutListening = shortcutListening
        let shortcut = KeyboardShortcutDefinition.displayName(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        )
        shortcutStatusText = detail ?? (shortcutListening ? "\(shortcut) 监听正常" : "\(shortcut) 未注册")
        isAccessibilityTrusted = AccessibilityService.isTrusted(prompt: false)
    }

    func setHotkeyKeyCode(_ keyCode: UInt32) {
        applyHotkey(keyCode: keyCode, modifiers: settings.hotkeyModifiers)
    }

    func setHotkeyModifier(_ modifier: ShortcutModifier, enabled: Bool) {
        var modifiers = settings.hotkeyModifiers
        if enabled {
            modifiers |= modifier.carbonMask
        } else {
            modifiers &= ~modifier.carbonMask
        }
        applyHotkey(keyCode: settings.hotkeyKeyCode, modifiers: modifiers)
    }

    func resetHotkey() {
        applyHotkey(
            keyCode: KeyboardShortcutDefinition.defaultKeyCode,
            modifiers: KeyboardShortcutDefinition.defaultModifiers
        )
    }

    private func applyHotkey(keyCode: UInt32, modifiers: UInt32) {
        if let message = KeyboardShortcutDefinition.validationMessage(
            keyCode: keyCode,
            modifiers: modifiers
        ) {
            showToast(message)
            return
        }
        var updatedSettings = settings
        updatedSettings.hotkeyKeyCode = keyCode
        updatedSettings.hotkeyModifiers = modifiers
        settings = updatedSettings
        showToast("快捷键已改为 \(KeyboardShortcutDefinition.displayName(keyCode: keyCode, modifiers: modifiers))")
    }

    func enrichAllMissingTags(in scopeIDs: Set<UUID>? = nil) {
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = settings.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty, !baseURL.isEmpty else {
            showToast("请先填写 API Key、模型名和 Base URL")
            return
        }

        let ids = snippets
            .filter { snippet in
                (scopeIDs?.contains(snippet.id) ?? true)
                    && snippet.tags.isEmpty
                    && !snippet.isEnriching
                    && !snippet.enrichmentFailed
                    && hasPotentialEnrichmentText(snippet)
            }
            .map(\.id)

        guard !ids.isEmpty else {
            showToast("没有需要生成标签的内容")
            return
        }

        showToast("开始生成 \(ids.count) 条标签")
        for id in ids {
            enrichSnippetIfNeeded(id, force: true)
        }
    }

    func retryEnrichment(for snippet: Snippet) {
        enrichSnippetIfNeeded(snippet.id, force: true, retryFailed: true)
    }

    func enableLaunchAtLoginAndKeepRunning() {
        settings.launchAtLogin = true
        LaunchAtLogin.setEnabled(true)
        showToast("已加入开机启动。快捷键在 App 运行时生效")
    }

    func useDeepSeekPreset() {
        settings.aiBaseURL = "https://api.deepseek.com/chat/completions"
        settings.aiModel = "deepseek-v4-flash"
        settings.aiEnrichment = true
        showToast("已切换到 DeepSeek")
    }

    func useOpenAIPreset() {
        settings.aiBaseURL = "https://api.openai.com/v1/chat/completions"
        settings.aiModel = "gpt-4o-mini"
        settings.aiEnrichment = true
        showToast("已切换到 OpenAI 推荐模型")
    }

    func copy(_ snippet: Snippet) {
        guard writeSnippetToPasteboard(snippet) else {
            showToast("内容复制失败")
            return
        }
        showToast("已复制")
    }

    func paste(_ snippet: Snippet, autoPaste: Bool) {
        copy(snippet)
        guard autoPaste else {
            return
        }
        let shouldPrompt = !didPromptForPasteAccessibility
        didPromptForPasteAccessibility = true
        guard AccessibilityService.isTrusted(prompt: shouldPrompt) else {
            showToast("需要开启辅助功能权限才能自动粘贴")
            return
        }
        NSApp.keyWindow?.orderOut(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(snippet.kind == .screenshot ? 260 : 120))
            AccessibilityService.sendCommandV()
            showToast("已粘贴")
        }
    }

    func copyAndPaste(_ selectedSnippets: [Snippet]) {
        guard !selectedSnippets.isEmpty else {
            showToast("请先选择要复制粘贴的内容")
            return
        }
        let shouldPrompt = !didPromptForPasteAccessibility
        didPromptForPasteAccessibility = true
        guard AccessibilityService.isTrusted(prompt: shouldPrompt) else {
            showToast("需要开启辅助功能权限才能自动粘贴")
            return
        }

        NSApp.keyWindow?.orderOut(nil)
        Task { @MainActor [weak self] in
            guard let self else { return }
            var pastedCount = 0
            for (index, snippet) in selectedSnippets.enumerated() {
                let isLast = index == selectedSnippets.count - 1
                if let text = exportText(for: snippet), !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text + (isLast ? "" : "\n\n"), forType: .string)
                    markInternalPasteboardWrite()
                } else if !writeSnippetToPasteboard(snippet) {
                    continue
                }
                try? await Task.sleep(for: .milliseconds(snippet.kind == .screenshot ? 300 : 130))
                AccessibilityService.sendCommandV()
                pastedCount += 1
                try? await Task.sleep(for: .milliseconds(snippet.kind == .screenshot ? 520 : 120))
            }
            showToast("已按当前顺序复制粘贴 \(pastedCount) 条")
        }
    }

    func importCurrentPasteboard() {
        addPasteboardContents(source: .manualPasteboardImport)
    }

    func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(makeDiagnostics().rendered, forType: .string)
        markInternalPasteboardWrite()
        showToast("已复制诊断信息")
    }

    func makeDiagnostics() -> SupportDiagnostics {
        SupportDiagnostics(
            appVersion: AppMetadata.version,
            appBuild: AppMetadata.build,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            snippetCount: snippets.count,
            filteredSnippetCount: filteredSnippets.count,
            draftBlockCount: draftSnippetIDs.count,
            monitorClipboard: settings.monitorClipboard,
            autoPaste: settings.autoPaste,
            persistSnippets: settings.persistSnippets,
            launchAtLogin: settings.launchAtLogin,
            aiEnrichment: settings.aiEnrichment,
            aiProviderHost: SupportDiagnostics.providerHost(from: settings.aiBaseURL),
            aiModel: settings.aiModel,
            shortcutStatus: shortcutStatusText,
            accessibilityTrusted: isAccessibilityTrusted
        )
    }

    func loadDemoSnippets() {
        let existingDemoTitles = Set(DemoContent.makeSnippets().map(\.title))
        snippets.removeAll { existingDemoTitles.contains($0.title) }
        snippets.insert(contentsOf: DemoContent.makeSnippets(), at: 0)
        persist()
        showToast("已载入示例片段")
    }

    func applyVideoDemoCommand(_ command: String) {
        guard isVideoDemo else { return }
        switch command {
        case "reset":
            searchText = ""
            selectedTags.removeAll()
            selectedTimeFilter = nil
            selectedDateRange = nil
            favoritesOnly = false
            draftSnippetIDs.removeAll()
            draftTextSlots.removeAll()
            polishedDraftText = ""
            polishedDraftSourceText = ""
            isPolishingDraft = false
            toast = nil
        case "filter":
            searchText = ""
            selectedTags = ["AI"]
            selectedTimeFilter = .today
            selectedDateRange = nil
            favoritesOnly = true
            draftSnippetIDs.removeAll()
            draftTextSlots.removeAll()
            toast = nil
        case "search":
            searchText = "表格"
            selectedTags.removeAll()
            selectedTimeFilter = nil
            selectedDateRange = nil
            favoritesOnly = false
            draftSnippetIDs.removeAll()
            draftTextSlots.removeAll()
            toast = nil
        case "first-block":
            guard let first = snippets.first else { return }
            searchText = ""
            selectedTags.removeAll()
            selectedTimeFilter = nil
            favoritesOnly = false
            draftSnippetIDs = [first.id]
            draftTextSlots.removeAll()
        case "second-block":
            guard snippets.count >= 2 else { return }
            searchText = ""
            selectedTags.removeAll()
            selectedTimeFilter = nil
            favoritesOnly = false
            draftSnippetIDs = [snippets[0].id, snippets[1].id]
            draftTextSlots.removeAll()
        case "bridge-text":
            guard snippets.count >= 2 else { return }
            searchText = ""
            selectedTags.removeAll()
            selectedTimeFilter = nil
            favoritesOnly = false
            draftSnippetIDs = [snippets[0].id, snippets[1].id]
            draftTextSlots["before-\(snippets[1].id.uuidString)"] = "结合表格证据，进一步说明"
        case "polishing":
            guard snippets.count >= 2 else { return }
            draftSnippetIDs = [snippets[0].id, snippets[1].id]
            draftTextSlots["before-\(snippets[1].id.uuidString)"] = "结合表格证据，进一步说明"
            polishedDraftText = ""
            polishedDraftSourceText = ""
            isPolishingDraft = true
            toast = ToastMessage(text: "AI 正在整理")
        case "polished":
            guard snippets.count >= 2 else { return }
            isPolishingDraft = false
            draftSnippetIDs = [snippets[0].id, snippets[1].id]
            draftTextSlots["before-\(snippets[1].id.uuidString)"] = "结合表格证据，进一步说明"
            acceptAIResult("""
            先提炼多个 AI 回答的共同结论，再保留关键差异；结合表格证据核对结构、表达与信息完整度，最终整理成一段可直接继续使用的提示词。
            """)
            toast = ToastMessage(text: "AI 整理完成")
        case "copied":
            isPolishingDraft = false
            showToast(hasCurrentPolishedDraft ? "已复制 AI 整理结果" : "已复制组合框原文")
        default:
            break
        }
    }

    private func pollVideoDemoCommand() {
        guard isVideoDemo else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LingganVideoDemo.command")
        guard let raw = try? String(contentsOf: url, encoding: .utf8), raw != lastVideoDemoCommand else {
            return
        }
        lastVideoDemoCommand = raw
        let command = raw.split(separator: ":", maxSplits: 1).first.map(String.init) ?? raw
        applyVideoDemoCommand(command)
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "导出灵感悬浮球备份"
        panel.nameFieldStringValue = "linggan-floating-ball-backup-\(Self.fileDateFormatter.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let backup = ClipboardBackupCodec.makeBackup(
                snippets: snippets,
                settings: settings,
                appVersion: AppMetadata.version
            )
            let data = try ClipboardBackupCodec.encode(backup)
            try data.write(to: url, options: [.atomic])
            showToast("已导出 \(backup.snippets.count) 条片段")
        } catch {
            showToast("备份导出失败")
        }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "导入灵感悬浮球备份"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let backup = try ClipboardBackupCodec.decode(try Data(contentsOf: url))
            let restoredSnippets = try restoreBackupAttachments(backup)
            var importedSettings = backup.settings
            importedSettings.persistSnippets = true
            snippets = restoredSnippets.sorted { $0.createdAt > $1.createdAt }
            settings = importedSettings
            persist()
            showToast("已导入 \(snippets.count) 条片段")
        } catch ClipboardBackupError.unsupportedVersion {
            showToast("备份版本过新，无法导入")
        } catch {
            showToast("备份导入失败")
        }
    }

    func exportMarkdown() {
        let snippetsToExport = filteredSnippets
        guard !snippetsToExport.isEmpty else {
            showToast("没有可导出的片段")
            return
        }

        let panel = NSSavePanel()
        panel.title = "导出 Markdown"
        panel.nameFieldStringValue = "linggan-floating-ball-\(Self.fileDateFormatter.string(from: Date())).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let markdown = MarkdownExport.render(snippets: snippetsToExport)
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            showToast("已导出 \(snippetsToExport.count) 条 Markdown")
        } catch {
            showToast("Markdown 导出失败")
        }
    }

    func shouldIgnorePasteboardChange(_ changeCount: Int) -> Bool {
        ignoredPasteboardChangeCounts.remove(changeCount) != nil
    }

    func ignorePasteboardChange(_ changeCount: Int) {
        ignoredPasteboardChangeCounts.insert(changeCount)
    }

    func showToast(_ text: String) {
        toast = ToastMessage(text: text)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if self?.toast?.text == text {
                    self?.toast = nil
                }
            }
        }
    }

    private func markInternalPasteboardWrite() {
        ignoredPasteboardChangeCounts.insert(NSPasteboard.general.changeCount)
        if ignoredPasteboardChangeCounts.count > 12 {
            ignoredPasteboardChangeCounts.remove(ignoredPasteboardChangeCounts.min() ?? 0)
        }
    }

    private func writeSnippetToPasteboard(_ snippet: Snippet) -> Bool {
        NSPasteboard.general.clearContents()
        let didWrite: Bool
        if snippet.effectiveRepresentation == .image {
            if snippet.kind == .screenshot, !snippet.allAttachmentPaths.isEmpty {
                didWrite = writeImagesToPasteboard(paths: snippet.allAttachmentPaths)
            } else if let pngData = TextImageRenderer.pngData(text: snippet.text, title: snippet.title) {
                didWrite = writeImageDataToPasteboard(pngData)
            } else {
                didWrite = false
            }
        } else if snippet.kind == .screenshot {
            let text = screenshotText(for: snippet) ?? ""
            didWrite = !text.isEmpty && NSPasteboard.general.setString(text, forType: .string)
        } else if let attachmentPath = snippet.attachmentPath {
            if snippet.kind == .spreadsheet {
                didWrite = NSPasteboard.general.setString(snippet.text, forType: .string)
            } else {
                let url = URL(fileURLWithPath: attachmentPath)
                didWrite = NSPasteboard.general.writeObjects([url as NSURL])
            }
        } else {
            didWrite = NSPasteboard.general.setString(snippet.text, forType: .string)
        }
        if didWrite {
            markInternalPasteboardWrite()
        }
        return didWrite
    }

    private func restoreBackupAttachments(_ backup: ClipboardBackup) throws -> [Snippet] {
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        let attachmentMap = Dictionary(grouping: backup.attachments, by: \.snippetID)
        return try backup.snippets.map { snippet in
            var restored = snippet
            restored.isEnriching = false
            if let attachments = attachmentMap[snippet.id], !attachments.isEmpty {
                var paths: [String] = []
                var names: [String] = []
                for attachment in attachments {
                    let fileName = uniqueBackupFileName(attachment.fileName)
                    let url = attachmentsDirectory.appendingPathComponent(fileName)
                    try attachment.data.write(to: url, options: [.atomic])
                    paths.append(url.path)
                    names.append(fileName)
                }
                restored.attachmentPath = paths.first
                restored.fileName = names.first
                restored.attachmentPaths = paths
                restored.attachmentFileNames = names
            } else if !snippet.allAttachmentPaths.isEmpty {
                restored.attachmentPath = nil
                restored.fileName = nil
                restored.attachmentPaths = []
                restored.attachmentFileNames = []
            }
            return restored
        }
    }

    private func uniqueBackupFileName(_ fileName: String) -> String {
        let fallback = "attachment-\(UUID().uuidString)"
        let safeName = fileName.isEmpty ? fallback : URL(fileURLWithPath: fileName).lastPathComponent
        let candidate = attachmentsDirectory.appendingPathComponent(safeName)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return safeName
        }
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        let unique = "\(stem)-\(UUID().uuidString.prefix(8))"
        return ext.isEmpty ? unique : "\(unique).\(ext)"
    }

    private func draftSlotKey(before id: UUID) -> String {
        "before-\(id.uuidString)"
    }

    private var draftSlotAfterAllKey: String {
        "after-all"
    }

    private func draftSlotText(before id: UUID) -> String? {
        draftTextSlots[draftSlotKey(before: id)]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func draftSlotTextAfterAll() -> String? {
        draftTextSlots[draftSlotAfterAllKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func exportText(for snippet: Snippet) -> String? {
        if snippet.kind == .screenshot {
            return screenshotText(for: snippet)
        }
        return snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasPotentialEnrichmentText(_ snippet: Snippet) -> Bool {
        if !snippet.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return snippet.kind == .screenshot && !snippet.allAttachmentPaths.isEmpty
    }

    private func screenshotText(for snippet: Snippet) -> String? {
        let existing = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty, !snippet.allAttachmentPaths.contains(existing) {
            return existing
        }
        let recognized = snippet.allAttachmentPaths
            .compactMap { Self.recognizedText(from: URL(fileURLWithPath: $0)) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !recognized.isEmpty else {
            return nil
        }
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].text = recognized
            if snippets[index].title.hasPrefix("截图") {
                snippets[index].title = Self.makeTitle(from: recognized)
            }
            persist()
        }
        return recognized
    }

    private func writeImagesToPasteboard(paths: [String]) -> Bool {
        let items = paths.compactMap { path -> NSPasteboardItem? in
            guard let image = NSImage(contentsOfFile: path),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            let item = NSPasteboardItem()
            item.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))
            item.setData(tiffData, forType: NSPasteboard.PasteboardType("public.tiff"))
            return item
        }
        guard !items.isEmpty else { return false }
        return NSPasteboard.general.writeObjects(items)
    }

    private func writeImageDataToPasteboard(_ pngData: Data, tiffData: Data? = nil) -> Bool {
        let item = NSPasteboardItem()
        item.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))
        if let tiffData {
            item.setData(tiffData, forType: NSPasteboard.PasteboardType("public.tiff"))
        }
        return NSPasteboard.general.writeObjects([item])
    }

    private func persist() {
        guard didFinishInitialLoad, !isVideoDemo else { return }
        let persistedSnippets = settings.persistSnippets ? snippets : []
        let persistedDeletedSnippets = settings.persistSnippets ? deletedSnippets : []
        persistentStore.save(PersistedState(
            snippets: persistedSnippets,
            deletedSnippets: persistedDeletedSnippets,
            settings: settings,
            quickNoteText: quickNoteText
        ))
    }

    private func expireFishMemory(now: Date = Date()) {
        guard !isVideoDemo else { return }
        let expired = snippets.filter {
            !$0.isFavorite && Self.shouldMoveToMemoryShore(createdAt: $0.createdAt, now: now)
        }
        guard !expired.isEmpty else { return }
        let ids = Set(expired.map(\.id))
        moveToMemoryShore(expired, deletedAt: now)
        draftSnippetIDs.removeAll { ids.contains($0) }
        persist()
        showToast("\(expired.count) 条记忆已进入回忆浅滩")
    }

    private func moveToMemoryShore(_ removed: [Snippet], deletedAt: Date = Date()) {
        guard !removed.isEmpty else { return }
        let existingIDs = Set(deletedSnippets.map(\.id))
        deletedSnippets.insert(
            contentsOf: removed
                .filter { !existingIDs.contains($0.id) }
                .map { DeletedSnippet(snippet: $0, deletedAt: deletedAt) },
            at: 0
        )
        let ids = Set(removed.map(\.id))
        snippets.removeAll { ids.contains($0.id) }
    }

    @discardableResult
    private func importSupportedURLs(_ urls: [URL], source: SnippetSource) -> Bool? {
        var imported = false
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ["xlsx", "xls", "csv"].contains(ext) {
                addAttachmentFile(from: url, kind: .spreadsheet, source: source)
                imported = true
            } else if ["png", "jpg", "jpeg", "heic", "tiff", "gif"].contains(ext) {
                addAttachmentFile(from: url, kind: .screenshot, source: source)
                imported = true
            }
        }
        return imported
    }

    private func copyAttachment(from sourceURL: URL) -> URL? {
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let safeName = baseName.replacingOccurrences(of: "/", with: "-")
        let suffix = Self.fileDateFormatter.string(from: Date())
        let fileName = ext.isEmpty ? "\(safeName)-\(suffix)" : "\(safeName)-\(suffix).\(ext)"
        let destination = attachmentsDirectory.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func titleForAttachment(fileName: String, kind: SnippetKind) -> String {
        switch kind {
        case .screenshot:
            return "截图 \(Self.displayDateFormatter.string(from: Date()))"
        case .spreadsheet:
            return "表格 \(fileName)"
        case .file:
            return fileName
        case .text:
            return fileName
        }
    }

    private func enrichSnippetIfNeeded(_ id: UUID, force: Bool = false, retryFailed: Bool = false) {
        guard settings.aiEnrichment || force else {
            return
        }
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = settings.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty, !baseURL.isEmpty else {
            showToast("AI 标题/标签未配置完整")
            return
        }
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard snippets[index].tags.isEmpty || force else {
            return
        }
        guard retryFailed || !snippets[index].enrichmentFailed else {
            return
        }
        let text = (exportText(for: snippets[index]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            markEnrichmentFailed(id: id, message: "没有可发送给 AI 的文字")
            return
        }

        snippets[index].isEnriching = true
        snippets[index].enrichmentFailed = false
        snippets[index].enrichmentError = nil
        persist()

        let existingTags = frequentTags.map(\.tag)
        Task { [weak self] in
            do {
                let result = try await self?.enricher.enrich(
                    text: text,
                    existingTags: existingTags,
                    baseURL: baseURL,
                    model: model,
                    apiKey: key
                )
                await MainActor.run {
                    self?.applyEnrichment(result, to: id)
                }
            } catch {
                await MainActor.run {
                    self?.markEnrichmentFailed(id: id, message: Self.shortError(error))
                    self?.handleAIError(error, prefix: "AI 生成失败")
                }
            }
        }
    }

    func applyEnrichment(_ enrichment: AIEnrichment?, to id: UUID) {
        guard let enrichment,
              let index = snippets.firstIndex(where: { $0.id == id }) else {
            markEnrichmentFailed(id: id, message: "AI 没有返回可用内容")
            return
        }
        let tags = Array(
            TagNormalization.unique(enrichment.tags, maximumLength: 10)
                .prefix(3)
        )
        guard !tags.isEmpty else {
            markEnrichmentFailed(id: id, message: "AI 没有返回标签")
            return
        }
        let title = enrichment.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            snippets[index].title = title
        }
        snippets[index].tags = tags
        snippets[index].isEnriching = false
        snippets[index].enrichmentFailed = false
        snippets[index].enrichmentError = nil
        persist()
        showToast("已生成标题和标签")
    }

    private func markEnrichmentFailed(id: UUID, message: String) {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            return
        }
        snippets[index].isEnriching = false
        snippets[index].enrichmentFailed = true
        snippets[index].enrichmentError = message
        persist()
    }

    private static func makeTitle(from text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 36 {
            return trimmed.isEmpty ? "未命名片段" : trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 36)
        return String(trimmed[..<index]) + "..."
    }

    private static func recognizedText(from url: URL) -> String? {
        OCRTextRecognizer.recognize(url: url)
    }

    private static func shortError(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "未知错误"
        }
        return String(message.prefix(140))
    }

    private func handleAIError(_ error: Error, prefix: String) {
        if Self.isQuotaError(error) {
            settings.aiEnrichment = false
            showToast("\(prefix)：API 额度不足，已暂停自动生成。请检查 Billing/限额或更换 Key")
            return
        }
        showToast("\(prefix)：\(Self.shortError(error))")
    }

    private func repairDeepSeekSettingsIfNeeded() {
        let url = settings.aiBaseURL.lowercased()
        let model = settings.aiModel.lowercased()
        var repaired = false

        if url.contains("platform.deepseek.com") || url.contains("/api_keys") {
            settings.aiBaseURL = "https://api.deepseek.com/chat/completions"
            repaired = true
        }

        if model == "deepseek-v4" || model == "deepseek-v4.0" || model == "deepseek-v4 " || model == "deepseek-v4".lowercased()
            || settings.aiModel == "DeepSeek-V4" {
            settings.aiModel = "deepseek-v4-flash"
            repaired = true
        }

        if repaired {
            settings.aiEnrichment = true
        }
    }

    private func repairShortcutIfNeeded() {
        guard KeyboardShortcutDefinition.isSupported(keyCode: settings.hotkeyKeyCode),
              KeyboardShortcutDefinition.validationMessage(
                  keyCode: settings.hotkeyKeyCode,
                  modifiers: settings.hotkeyModifiers
              ) == nil else {
            var repairedSettings = settings
            repairedSettings.hotkeyKeyCode = KeyboardShortcutDefinition.defaultKeyCode
            repairedSettings.hotkeyModifiers = KeyboardShortcutDefinition.defaultModifiers
            settings = repairedSettings
            return
        }
    }

    private static func isQuotaError(_ error: Error) -> Bool {
        guard case let AIEnrichmentError.httpStatus(status, message) = error else {
            return false
        }
        return status == 429 && message.localizedCaseInsensitiveContains("quota")
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()
}
