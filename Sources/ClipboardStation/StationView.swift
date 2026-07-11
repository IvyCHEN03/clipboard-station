import AppKit
import SwiftUI

struct StationView: View {
    @ObservedObject var store: SnippetStore
    @State private var isPinned = false
    @State private var showSettings = false
    @State private var draggingSnippetID: UUID?
    @State private var draggingDraftID: UUID?
    @State private var selectedSnippetIDs = Set<UUID>()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !showSettings && !store.frequentTags.isEmpty {
                keywordBar
            }
            searchBar
            if !showSettings && !store.filteredSnippets.isEmpty {
                selectionBar
            }
            content
            Divider()
            DraftDock(store: store, draggingSnippetID: $draggingSnippetID, draggingDraftID: $draggingDraftID)
        }
        .frame(minWidth: 420, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Text(toast.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.82), in: Capsule())
                    .padding(.bottom, 54)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
    }

    private var header: some View {
        HStack(spacing: 10) {
            BubbleLogo()

            VStack(alignment: .leading, spacing: 2) {
                Text("灵感悬浮球")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(AppMetadata.displayVersion) 积木组合版 · \(store.filteredSnippets.count)/\(store.snippets.count) 个片段")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            IconButton(systemName: isPinned ? "pin.fill" : "pin", help: "置顶浮窗") {
                isPinned.toggle()
                NSApp.windows.first(where: { $0.isVisible })?.level = isPinned ? .floating : .normal
            }

            IconButton(systemName: "gearshape", help: "设置") {
                showSettings.toggle()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var keywordBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            filterRow(title: "时间") {
                ForEach(TimeFilter.allCases) { filter in
                    timeFilterButton(filter)
                }
            }

            filterRow(title: "分类") {
                ForEach(store.frequentTags) { item in
                    tagFilterButton(item)
                }
            }
        }
        .padding(.top, 8)
    }

    private func filterRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    content()
                }
                .padding(.trailing, 14)
            }
        }
        .padding(.leading, 14)
    }

    private func timeFilterButton(_ filter: TimeFilter) -> some View {
        Button {
            if store.selectedTimeFilter == filter {
                store.selectedTimeFilter = nil
            } else {
                store.selectedTimeFilter = filter
            }
        } label: {
            Text(filter.label)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    store.selectedTimeFilter == filter
                        ? Color(red: 0.38, green: 0.72, blue: 1.0).opacity(0.22)
                        : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .help("按时间筛选：\(filter.label)")
    }

    private func tagFilterButton(_ item: KeywordStat) -> some View {
        Button {
            store.toggleTagFilter(item.tag)
        } label: {
            HStack(spacing: 4) {
                if store.selectedTags.contains(item.tag) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(item.tag)
                    .lineLimit(1)
                Text("\(item.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                store.selectedTags.contains(item.tag)
                    ? Color(red: 0.38, green: 0.72, blue: 1.0).opacity(0.2)
                    : Color.secondary.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .help(store.selectedTags.contains(item.tag) ? "取消筛选“\(item.tag)”" : "筛选包含“\(item.tag)”的片段")
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索标题、正文或来源", text: $store.searchText)
                .textFieldStyle(.plain)
            if !store.searchText.isEmpty || !store.selectedTags.isEmpty || store.selectedTimeFilter != nil {
                IconButton(systemName: "xmark.circle.fill", help: "清除搜索") {
                    store.searchText = ""
                    store.selectedTags.removeAll()
                    store.selectedTimeFilter = nil
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Text(selectedSnippetIDs.isEmpty ? "未选择片段" : "已选择 \(selectedSnippetIDs.count) 条")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("当前 \(store.filteredSnippets.count) 条")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                selectedSnippetIDs = Set(store.filteredSnippets.map(\.id))
            } label: {
                Label("全选", systemImage: "checkmark.square")
            }
            .buttonStyle(.borderless)

            Button {
                selectedSnippetIDs.removeAll()
            } label: {
                Label("取消", systemImage: "xmark.square")
            }
            .buttonStyle(.borderless)
            .disabled(selectedSnippetIDs.isEmpty)

            Button {
                store.enrichAllMissingTags()
            } label: {
                Label("Tag", systemImage: "tag")
            }
            .buttonStyle(.borderless)
            .help("待处理 \(store.pendingTagCount) · 进行中 \(store.runningTagCount) · 失败 \(store.failedTagCount)")

            Text("\(store.pendingTagCount)/\(store.runningTagCount)/\(store.failedTagCount)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(store.failedTagCount > 0 ? .orange : .secondary)
                .help("待处理 / 进行中 / 失败")

            Button(role: .destructive) {
                store.delete(ids: selectedSnippetIDs)
                selectedSnippetIDs.removeAll()
            } label: {
                Label("删除", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(selectedSnippetIDs.isEmpty)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if showSettings {
            SettingsView(store: store)
        } else if store.filteredSnippets.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.filteredSnippets) { snippet in
                        SnippetRow(
                            snippet: snippet,
                            store: store,
                            isSelected: selectedSnippetIDs.contains(snippet.id)
                        ) {
                            toggleSelection(snippet.id)
                        }
                            .opacity(draggingSnippetID == snippet.id ? 0.55 : 1)
                            .onDrag {
                                draggingSnippetID = snippet.id
                                return snippetDragProvider(for: snippet)
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                BubbleLogo()
                VStack(alignment: .leading, spacing: 3) {
                    Text("开始收集灵感")
                        .font(.system(size: 16, weight: .semibold))
                    Text("复制文字、截图或表格后，它们会出现在这里。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                QuickStartStep(number: "1", title: "复制内容", detail: "在任意 App 里复制文字、截图或表格。")
                QuickStartStep(number: "2", title: "打开悬浮球", detail: "点击屏幕边缘的小泡泡，或使用菜单栏图标。")
                QuickStartStep(number: "3", title: "组合输出", detail: "把片段拖到组合框，加入补充文字后复制。")
            }

            HStack(spacing: 8) {
                Button {
                    store.importCurrentPasteboard()
                } label: {
                    Label("导入当前剪贴板", systemImage: "square.and.arrow.down")
                }

                Button {
                    showSettings = true
                } label: {
                    Label("检查设置", systemImage: "gearshape")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedSnippetIDs.contains(id) {
            selectedSnippetIDs.remove(id)
        } else {
            selectedSnippetIDs.insert(id)
        }
    }

}

private struct SnippetRow: View {
    let snippet: Snippet
    @ObservedObject var store: SnippetStore
    let isSelected: Bool
    let toggleSelection: () -> Void
    @State private var title: String
    @State private var isEditingTitle = false
    @State private var orderText: String

    init(snippet: Snippet, store: SnippetStore, isSelected: Bool, toggleSelection: @escaping () -> Void) {
        self.snippet = snippet
        self.store = store
        self.isSelected = isSelected
        self.toggleSelection = toggleSelection
        _title = State(initialValue: snippet.title)
        _orderText = State(initialValue: "\(store.displayIndex(for: snippet) ?? 1)")
    }

    var body: some View {
        let displayIndex = store.displayIndex(for: snippet) ?? 1
        let orderColor = snippetOrderColor(displayIndex - 1)

        HStack(alignment: .top, spacing: 8) {
            Button(action: toggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? orderColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isSelected ? "取消选择" : "选择")
            .padding(.top, 5)

            VStack(spacing: 4) {
                IconButton(systemName: "chevron.up", help: "上移") {
                    store.moveSnippetUp(snippet)
                    syncOrderText()
                }
                TextField("", text: $orderText, onCommit: applyOrder)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .background(orderColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(orderColor.opacity(0.55))
                    }
                    .foregroundStyle(orderColor)
                    .help("输入序号后回车排序")
                IconButton(systemName: "chevron.down", help: "下移") {
                    store.moveSnippetDown(snippet)
                    syncOrderText()
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    if isEditingTitle {
                        TextField("标题", text: $title, onCommit: saveTitle)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(snippet.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    IconButton(systemName: isEditingTitle ? "checkmark" : "pencil", help: isEditingTitle ? "保存标题" : "编辑标题") {
                        if isEditingTitle {
                            saveTitle()
                        } else {
                            isEditingTitle = true
                        }
                    }
                    IconButton(systemName: "doc.on.doc", help: "复制") {
                        store.copy(snippet)
                    }
                    IconButton(systemName: "arrow.down.doc", help: "粘贴到当前输入框") {
                        store.paste(snippet, autoPaste: store.settings.autoPaste)
                    }
                    IconButton(systemName: "trash", help: "删除", role: .destructive) {
                        store.delete(snippet)
                    }
                }

                SnippetBody(snippet: snippet)

                if snippet.isEnriching || !snippet.tags.isEmpty || snippet.enrichmentFailed {
                    HStack(spacing: 6) {
                        if snippet.isEnriching {
                            ProgressView()
                                .controlSize(.small)
                            Text("生成中")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(snippet.tags, id: \.self) { tag in
                            Text(tag)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                        if snippet.enrichmentFailed {
                            Label("打标失败", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help(snippet.enrichmentError ?? "AI 生成失败")
                            Button {
                                store.retryEnrichment(for: snippet)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                            .help("重试这一条")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                }

                HStack(spacing: 8) {
                    Text(snippet.kind.label)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    Label(snippet.source.label, systemImage: sourceIcon)
                    Text(Self.dateFormatter.string(from: snippet.createdAt))
                    Text("\(snippet.charCount) 字")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(isSelected ? orderColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? orderColor.opacity(0.35) : Color.clear)
        }
        .onChange(of: snippet.title) { newValue in
            title = newValue
        }
        .onChange(of: store.snippets) { _ in
            syncOrderText()
        }
    }

    private var sourceIcon: String {
        switch snippet.source {
        case .hotkeySelection:
            return "keyboard"
        case .clipboardCopy:
            return "doc.on.clipboard"
        case .manualPasteboardImport:
            return "square.and.arrow.down"
        case .screenshot:
            return "camera.viewfinder"
        }
    }

    private func saveTitle() {
        store.updateTitle(for: snippet, title: title)
        isEditingTitle = false
    }

    private func syncOrderText() {
        if let index = store.displayIndex(for: snippet) {
            orderText = "\(index)"
        }
    }

    private func applyOrder() {
        guard let index = Int(orderText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            syncOrderText()
            return
        }
        store.moveSnippet(snippet, toDisplayIndex: index)
        syncOrderText()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct BubbleLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.93, blue: 1.0),
                            Color(red: 0.42, green: 0.74, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1, y: -1)
            Circle()
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
        }
        .frame(width: 28, height: 28)
        .shadow(color: Color(red: 0.42, green: 0.74, blue: 1.0).opacity(0.25), radius: 4, y: 2)
        .accessibilityLabel("灵感悬浮球")
    }
}

private struct SnippetBody: View {
    let snippet: Snippet

    var body: some View {
        if snippet.attachmentPath == nil && (snippet.kind == .text || snippet.kind == .spreadsheet) {
            Text(snippet.text)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(5)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if snippet.kind == .screenshot {
            if let attachmentPath = snippet.attachmentPath,
               let image = NSImage(contentsOfFile: attachmentPath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 180, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.18))
                    }
                    .help(snippet.fileName ?? "截图")
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text(snippet.fileName ?? "截图")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                Text(snippet.fileName ?? snippet.title)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var store: SnippetStore

    var body: some View {
        Form {
            Section("首次使用") {
                OnboardingLine(
                    title: "入口",
                    detail: "优先使用屏幕边缘的小泡泡；快捷键只在 App 运行时生效。",
                    systemImage: "circle.grid.2x2"
                )
                OnboardingLine(
                    title: "收集",
                    detail: store.settings.monitorClipboard ? "普通复制会自动进入列表。" : "已关闭监听，可用底部 + 手动导入。",
                    systemImage: store.settings.monitorClipboard ? "doc.on.doc" : "plus.square"
                )
                OnboardingLine(
                    title: "输出",
                    detail: "把片段拖入组合框，可在积木之间补充文字。",
                    systemImage: "text.cursor"
                )
            }

            Section("运行状态") {
                StatusLine(
                    title: "App",
                    value: store.isAppRunning ? "正在运行" : "未运行",
                    systemImage: store.isAppRunning ? "checkmark.circle.fill" : "xmark.circle.fill",
                    tint: store.isAppRunning ? .green : .red
                )
                StatusLine(
                    title: "快捷键",
                    value: store.shortcutStatusText,
                    systemImage: store.isShortcutListening ? "keyboard.fill" : "keyboard",
                    tint: store.isShortcutListening ? .green : .orange
                )
                StatusLine(
                    title: "辅助功能",
                    value: store.isAccessibilityTrusted ? "已授权" : "需要辅助功能权限",
                    systemImage: store.isAccessibilityTrusted ? "figure.walk.circle.fill" : "figure.walk.circle",
                    tint: store.isAccessibilityTrusted ? .green : .orange
                )
                Text("快捷键只在灵感悬浮球正在运行时生效。退出 App 后，请从菜单栏图标或 .app 文件重新打开。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button {
                    store.enableLaunchAtLoginAndKeepRunning()
                } label: {
                    Label("一键加入开机启动并常驻", systemImage: "power.circle")
                }
            }

            Toggle("监听普通复制", isOn: $store.settings.monitorClipboard)
            Toggle("点击粘贴图标后自动 Cmd+V", isOn: $store.settings.autoPaste)
            Toggle("AI 生成标题和标签", isOn: $store.settings.aiEnrichment)
            Toggle("本地加密持久化保存", isOn: $store.settings.persistSnippets)
            Toggle("开机启动", isOn: $store.settings.launchAtLogin)

            HStack {
                Text("全局快捷键")
                Spacer()
                Text("Cmd+Shift+C")
                    .foregroundStyle(.secondary)
            }

            TextField("AI Base URL", text: $store.settings.aiBaseURL)
            TextField("模型名", text: $store.settings.aiModel)
            SecureField("API Key", text: $store.aiAPIKey)

            HStack {
                Button {
                    store.useDeepSeekPreset()
                } label: {
                    Label("切换 DeepSeek", systemImage: "sparkles")
                }
            }

            Button {
                store.testAIConnection()
            } label: {
                Label("测试 AI 连接", systemImage: "network")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

private struct QuickStartStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color(red: 0.38, green: 0.72, blue: 1.0), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingLine: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.38, green: 0.72, blue: 1.0))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StatusLine: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
    }
}

private struct DraftDock: View {
    @ObservedObject var store: SnippetStore
    @Binding var draggingSnippetID: UUID?
    @Binding var draggingDraftID: UUID?
    @FocusState private var isDraftExtraFocused: Bool
    @State private var activeDraftSlot: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(.secondary)
                Text("组合框")
                    .font(.system(size: 12, weight: .semibold))
                Text("拖入内容，按数字顺序组合")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                IconButton(systemName: "plus", help: "导入当前剪贴板") {
                    store.importCurrentPasteboard()
                }
                IconButton(systemName: "doc.on.doc", help: "复制组合内容") {
                    store.copyDraftText()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if store.draftSnippets.isEmpty {
                        Text("空")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(height: 30)
                    } else {
                        ForEach(Array(store.draftSnippets.enumerated()), id: \.element.id) { index, snippet in
                            DraftInsertionSlot(
                                id: slotID(before: snippet.id),
                                text: store.bindingForDraftSlot(before: snippet.id),
                                activeSlot: $activeDraftSlot
                            )
                            DraftBlock(
                                number: store.displayIndex(for: snippet) ?? index + 1,
                                color: blockColor(index),
                                kind: snippet.kind
                            ) {
                                store.removeDraftBlock(id: snippet.id)
                            }
                            .opacity(draggingDraftID == snippet.id ? 0.55 : 1)
                            .onDrag {
                                draggingDraftID = snippet.id
                                draggingSnippetID = snippet.id
                                return snippetDragProvider(for: snippet)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: DraftDropDelegate(
                                    targetID: snippet.id,
                                    draggingSnippetID: $draggingSnippetID,
                                    draggingDraftID: $draggingDraftID,
                                    store: store
                                )
                            )
                        }
                        DraftInsertionSlot(
                            id: "after-all",
                            text: store.bindingForDraftSlotAfterAll(),
                            activeSlot: $activeDraftSlot
                        )
                    }
                }
                .frame(minHeight: 34)
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.18))
            }
            .onDrop(
                of: [.text],
                delegate: DraftDropDelegate(
                    targetID: nil,
                    draggingSnippetID: $draggingSnippetID,
                    draggingDraftID: $draggingDraftID,
                    store: store
                )
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.draftExtraText)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .focused($isDraftExtraFocused)
                    .frame(minHeight: 58, maxHeight: 82)
                    .padding(6)
                if store.draftExtraText.isEmpty && !isDraftExtraFocused {
                    Text("在这里补充手写内容，复制组合时会一起带上")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.18))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func blockColor(_ index: Int) -> Color {
        snippetOrderColor(index)
    }

    private func slotID(before id: UUID) -> String {
        "before-\(id.uuidString)"
    }
}

private struct DraftBlock: View {
    let number: Int
    let color: Color
    let kind: SnippetKind
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if kind == .screenshot {
                Image(systemName: "photo")
                    .font(.system(size: 10, weight: .semibold))
            }
            Text("\(number)")
                .lineLimit(1)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 34, minHeight: 28)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
        .foregroundStyle(color)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(color.opacity(0.45))
        }
    }
}

private struct DraftInsertionSlot: View {
    let id: String
    @Binding var text: String
    @Binding var activeSlot: String?
    @FocusState private var isFocused: Bool

    private var isActive: Bool {
        activeSlot == id || !text.isEmpty
    }

    var body: some View {
        Group {
            if isActive {
                TextField("", text: $text, prompt: Text("+文字"))
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .frame(width: 86, height: 28)
                    .padding(.horizontal, 7)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isFocused ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.2))
                    }
                    .onSubmit {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            activeSlot = nil
                        }
                    }
                    .onAppear {
                        if activeSlot == id {
                            isFocused = true
                        }
                    }
            } else {
                Button {
                    activeSlot = id
                } label: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(width: 2, height: 24)
                        .padding(.horizontal, 5)
                }
                .buttonStyle(.plain)
                .help("在这里插入文字")
            }
        }
    }
}

private struct DraftDropDelegate: DropDelegate {
    let targetID: UUID?
    @Binding var draggingSnippetID: UUID?
    @Binding var draggingDraftID: UUID?
    @ObservedObject var store: SnippetStore

    func dropEntered(info: DropInfo) {
        guard let id = draggingSnippetID else {
            return
        }
        if draggingDraftID != nil {
            store.moveDraftBlock(id: id, before: targetID)
        } else {
            store.addToDraft(id: id, before: targetID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingSnippetID = nil
        draggingDraftID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct IconButton: View {
    let systemName: String
    let help: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private func snippetOrderColor(_ index: Int) -> Color {
    let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink]
    return colors[index % colors.count]
}

private func snippetDragProvider(for snippet: Snippet) -> NSItemProvider {
    let provider = NSItemProvider(object: snippet.id.uuidString as NSString)
    guard snippet.kind == .screenshot,
          let attachmentPath = snippet.attachmentPath else {
        return provider
    }

    let url = URL(fileURLWithPath: attachmentPath)
    provider.registerFileRepresentation(
        forTypeIdentifier: "public.png",
        fileOptions: [],
        visibility: .all
    ) { completion in
        completion(url, true, nil)
        return nil
    }
    provider.registerObject(url as NSURL, visibility: .all)
    return provider
}
