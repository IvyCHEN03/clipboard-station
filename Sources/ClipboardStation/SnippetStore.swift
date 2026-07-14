import AppKit
import Carbon
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Vision

@MainActor
final class SnippetStore: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var deletedSnippets: [DeletedSnippet] = []
    @Published var settings: StationSettings = .defaults {
        didSet {
            if oldValue != settings {
                persist()
                settingsChanged?(settings)
            }
        }
    }
    @Published var searchText = ""
    @Published var selectedTags = Set<String>()
    @Published var selectedTimeFilter: TimeFilter?
    @Published var toast: ToastMessage?
    @Published var draftExtraText = ""
    @Published var draftTextSlots: [String: String] = [:]
    @Published var aiAPIKey: String = "" {
        didSet {
            if oldValue != aiAPIKey {
                KeychainCredentials.save(aiAPIKey, account: "ai-api-key")
            }
        }
    }
    @Published var draftSnippetIDs: [UUID] = []
    @Published var isAppRunning = true
    @Published var isShortcutListening = false
    @Published var shortcutStatusText = "未启动监听"
    @Published var isAccessibilityTrusted = false

    var settingsChanged: ((StationSettings) -> Void)?

    private let persistentStore = PersistentStore()
    private let enricher = AIEnricher()
    private let attachmentsDirectory: URL
    private var toastTask: Task<Void, Never>?
    private var didPromptForPasteAccessibility = false
    private var ignoredPasteboardChangeCounts = Set<Int>()
    private var fishMemoryTimer: AnyCancellable?

    static let fishMemoryDuration: TimeInterval = 7 * 24 * 60 * 60

    var filteredSnippets: [Snippet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snippets.filter { snippet in
            let matchesText = query.isEmpty || snippet.matchesKeyword(query)
            let matchesTags = selectedTags.isEmpty || selectedTags.allSatisfy { snippet.matchesKeyword($0) }
            let matchesTime = selectedTimeFilter?.contains(snippet.createdAt) ?? true
            return matchesText && matchesTags && matchesTime
        }
    }

    var draftSnippets: [Snippet] {
        draftSnippetIDs.compactMap { id in
            snippets.first { $0.id == id }
        }
    }

    var frequentTags: [KeywordStat] {
        let counts = snippets
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { result, tag in
                result[tag, default: 0] += 1
            }
        return counts
            .map { KeywordStat(tag: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(12)
            .map { $0 }
    }

    var pendingTagCount: Int {
        snippets.filter { snippet in
            snippet.tags.isEmpty
                && !snippet.isEnriching
                && !snippet.enrichmentFailed
                && hasExportableText(snippet)
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
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        attachmentsDirectory = base
            .appendingPathComponent("ClipboardStation", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        let state = persistentStore.load()
        snippets = state.snippets.sorted { $0.createdAt > $1.createdAt }
        deletedSnippets = state.deletedSnippets.sorted { $0.deletedAt > $1.deletedAt }
        settings = state.settings
        aiAPIKey = KeychainCredentials.read(account: "ai-api-key")
        repairOpenHotkeyIfNeeded()
        repairDeepSeekSettingsIfNeeded()
        expireFishMemory()
        fishMemoryTimer = Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.expireFishMemory()
            }
        refreshRuntimeStatus(shortcutListening: false)
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
        let restored = deletedSnippets.remove(at: index).snippet
        snippets.insert(restored, at: 0)
        persist()
        showToast("已找回“\(restored.title)”")
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

    func addToDraft(id: UUID, before targetID: UUID? = nil) {
        guard snippets.contains(where: { $0.id == id }) else {
            return
        }
        draftSnippetIDs.removeAll { $0 == id }
        if let targetID, let targetIndex = draftSnippetIDs.firstIndex(of: targetID) {
            draftSnippetIDs.insert(id, at: targetIndex)
        } else {
            draftSnippetIDs.append(id)
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

    func copyDraftText() {
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
        parts.append(draftExtraText.trimmingCharacters(in: .whitespacesAndNewlines))
        let text = parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !text.isEmpty else {
            showToast("组合框没有可复制的文字")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        markInternalPasteboardWrite()
        showToast("已复制组合内容")
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
        shortcutStatusText = detail ?? (shortcutListening ? "Cmd+Shift+C 监听正常" : "Cmd+Shift+C 未注册")
        isAccessibilityTrusted = AccessibilityService.isTrusted(prompt: false)
    }

    func enrichAllMissingTags() {
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = settings.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty, !baseURL.isEmpty else {
            showToast("请先填写 API Key、模型名和 Base URL")
            return
        }

        let ids = snippets
            .filter { snippet in
                snippet.tags.isEmpty
                    && !snippet.isEnriching
                    && !snippet.enrichmentFailed
                    && !(exportText(for: snippet) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        NSPasteboard.general.clearContents()
        if snippet.kind == .screenshot,
           let text = screenshotText(for: snippet),
           !text.isEmpty {
            NSPasteboard.general.setString(text, forType: .string)
        } else if snippet.kind == .screenshot,
           let attachmentPath = snippet.attachmentPath {
            if !writeImageToPasteboard(path: attachmentPath) {
                showToast("图片复制失败")
                return
            }
        } else if let attachmentPath = snippet.attachmentPath {
            let url = URL(fileURLWithPath: attachmentPath)
            NSPasteboard.general.writeObjects([url as NSURL])
        } else {
            NSPasteboard.general.setString(snippet.text, forType: .string)
        }
        markInternalPasteboardWrite()
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

    private func restoreBackupAttachments(_ backup: ClipboardBackup) throws -> [Snippet] {
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        let attachmentMap = Dictionary(uniqueKeysWithValues: backup.attachments.map { ($0.snippetID, $0) })
        return try backup.snippets.map { snippet in
            var restored = snippet
            restored.isEnriching = false
            if let attachment = attachmentMap[snippet.id] {
                let fileName = uniqueBackupFileName(attachment.fileName)
                let url = attachmentsDirectory.appendingPathComponent(fileName)
                try attachment.data.write(to: url, options: [.atomic])
                restored.attachmentPath = url.path
                restored.fileName = fileName
            } else if snippet.attachmentPath != nil {
                restored.attachmentPath = nil
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

    private func hasExportableText(_ snippet: Snippet) -> Bool {
        !(exportText(for: snippet) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func screenshotText(for snippet: Snippet) -> String? {
        let existing = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty, existing != snippet.attachmentPath {
            return existing
        }
        guard let attachmentPath = snippet.attachmentPath,
              let recognized = Self.recognizedText(from: URL(fileURLWithPath: attachmentPath)),
              !recognized.isEmpty else {
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

    private func writeImageToPasteboard(path: String) -> Bool {
        guard let image = NSImage(contentsOfFile: path),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }

        let item = NSPasteboardItem()
        item.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))
        item.setData(tiffData, forType: NSPasteboard.PasteboardType("public.tiff"))
        return NSPasteboard.general.writeObjects([item])
    }

    private func persist() {
        let persistedSnippets = settings.persistSnippets ? snippets : []
        let persistedDeletedSnippets = settings.persistSnippets ? deletedSnippets : []
        persistentStore.save(PersistedState(
            snippets: persistedSnippets,
            deletedSnippets: persistedDeletedSnippets,
            settings: settings
        ))
    }

    private func expireFishMemory(now: Date = Date()) {
        let expired = snippets.filter { Self.shouldMoveToMemoryShore(createdAt: $0.createdAt, now: now) }
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

        Task { [weak self] in
            do {
                let result = try await self?.enricher.enrich(text: text, baseURL: baseURL, model: model, apiKey: key)
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

    private func applyEnrichment(_ enrichment: AIEnrichment?, to id: UUID) {
        guard let enrichment,
              let index = snippets.firstIndex(where: { $0.id == id }) else {
            markEnrichmentFailed(id: id, message: "AI 没有返回可用内容")
            return
        }
        let tags = enrichment.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            return nil
        }
        return lines.joined(separator: "\n")
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

    private func repairOpenHotkeyIfNeeded() {
        if settings.hotkeyKeyCode == UInt32(kVK_ANSI_O),
           settings.hotkeyModifiers == UInt32(cmdKey) {
            settings.hotkeyKeyCode = UInt32(kVK_ANSI_C)
            settings.hotkeyModifiers = UInt32(cmdKey | shiftKey)
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
