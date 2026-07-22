import AppKit
import SwiftUI

struct StationView: View {
    @ObservedObject var store: SnippetStore
    let quitApp: () -> Void
    let restartApp: () -> Void
    let setPinned: (Bool) -> Void
    @State private var isPinned = false
    @State private var showSettings = false
    @State private var showMemoryShore = false
    @State private var draggingSnippetID: UUID?
    @State private var draggingDraftID: UUID?
    @State private var selectedSnippetIDs = Set<UUID>()
    @State private var isRewound = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !showSettings && !showMemoryShore {
                keywordBar
            }
            if !showSettings && !showMemoryShore {
                searchBar
            }
            if !showSettings && !showMemoryShore && !store.filteredSnippets.isEmpty {
                selectionBar
            }
            content
            if !showSettings && !showMemoryShore {
                Divider()
                DraftDock(store: store, draggingSnippetID: $draggingSnippetID, draggingDraftID: $draggingDraftID)
            }
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
        .onChange(of: store.filteredSnippets.map(\.id)) { visibleIDs in
            selectedSnippetIDs.formIntersection(Set(visibleIDs))
        }
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

            Button {
                showMemoryShore.toggle()
                showSettings = false
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: showMemoryShore ? "tray.full.fill" : "tray.full")
                    if !store.deletedSnippets.isEmpty {
                        Text("\(min(store.deletedSnippets.count, 99))")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(.orange, in: Circle())
                            .offset(x: 6, y: -5)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("回忆浅滩：找回已删除内容")

            IconButton(systemName: isPinned ? "pin.fill" : "pin", help: isPinned ? "解除窗口固定" : "固定窗口位置并置顶") {
                isPinned.toggle()
                setPinned(isPinned)
            }

            IconButton(systemName: "gearshape", help: "设置") {
                showSettings.toggle()
                showMemoryShore = false
            }

            IconButton(systemName: "questionmark.circle", help: "打开使用指南") {
                ProjectLinks.open(.gettingStarted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var keywordBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("时间")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
                ForEach(TimeFilter.allCases) { filter in
                    timeSegmentButton(filter)
                }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 14)

            if !store.frequentTags.isEmpty {
                filterRow(title: "分类") {
                    ForEach(store.frequentTags) { item in
                        tagFilterButton(item)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func filterRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        return HStack(spacing: 8) {
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

    private func timeSegmentButton(_ filter: TimeFilter) -> some View {
        let color = timeSegmentColor(filter)
        let percentage = store.timeBucketPercentage(filter)
        return Button {
            if store.selectedTimeFilter == filter {
                store.selectedTimeFilter = nil
            } else {
                store.selectedTimeFilter = filter
            }
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.11))
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(store.selectedTimeFilter == filter ? 0.42 : 0.24))
                        .frame(width: proxy.size.width * CGFloat(percentage) / 100)
                }
                HStack(spacing: 4) {
                    Text(filter.label)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(percentage)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        store.selectedTimeFilter == filter ? color.opacity(0.85) : color.opacity(0.22),
                        lineWidth: store.selectedTimeFilter == filter ? 1.5 : 1
                    )
            }
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .help("筛选\(filter.label)的内容")
    }

    private func timeSegmentColor(_ filter: TimeFilter) -> Color {
        switch filter {
        case .today:
            return Color(red: 0.12, green: 0.62, blue: 0.92)
        case .threeDays:
            return Color(red: 0.18, green: 0.66, blue: 0.43)
        case .fishMemory:
            return Color(red: 0.94, green: 0.50, blue: 0.18)
        }
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
        let visibleIDs = Set(store.filteredSnippets.map(\.id))
        let visibleSelection = selectedSnippetIDs.intersection(visibleIDs)
        let allVisibleSelected = !visibleIDs.isEmpty && visibleSelection == visibleIDs
        let actionScope = visibleSelection.isEmpty ? visibleIDs : visibleSelection

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Button {
                    if allVisibleSelected {
                        selectedSnippetIDs.subtract(visibleIDs)
                        store.showToast("已取消当前选择")
                    } else {
                        selectedSnippetIDs = visibleIDs
                        store.showToast("已全选当前 \(visibleIDs.count) 条")
                    }
                } label: {
                    Label(
                        allVisibleSelected ? "取消" : "全选",
                        systemImage: allVisibleSelected ? "xmark.square" : "checkmark.square"
                    )
                }
                .buttonStyle(.borderless)
                .disabled(store.filteredSnippets.isEmpty)

                Button {
                    selectedSnippetIDs.subtract(visibleIDs)
                    store.showToast("已取消当前筛选中的选择")
                } label: {
                    Label("取消", systemImage: "xmark.square")
                }
                .buttonStyle(.borderless)
                .disabled(visibleSelection.isEmpty)

                Button {
                    let selected = displayedSnippets.filter { visibleSelection.contains($0.id) }
                    store.copyAndPaste(selected)
                } label: {
                    Label("复制", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .disabled(visibleSelection.isEmpty)
                .help("按当前显示顺序复制并粘贴已选的 \(visibleSelection.count) 条")

                Button {
                    store.enrichAllMissingTags(in: actionScope)
                } label: {
                    Label("Tag", systemImage: "tag")
                }
                .buttonStyle(.borderless)
                .help("仅处理当前范围 \(actionScope.count) 条 · 全局进行中 \(store.runningTagCount) · 失败 \(store.failedTagCount)")

                RewindControl(
                    isRewound: isRewound,
                    isEnabled: store.filteredSnippets.count >= 2,
                    onToggle: toggleRewindOrder,
                    onRestore: restoreNormalOrder
                )
                .frame(width: 52, height: 20)
                .fixedSize()

                Button(role: .destructive) {
                    store.delete(ids: visibleSelection)
                    selectedSnippetIDs.subtract(visibleSelection)
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(visibleSelection.isEmpty)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var displayedSnippets: [Snippet] {
        isRewound ? Array(store.filteredSnippets.reversed()) : store.filteredSnippets
    }

    private func toggleRewindOrder() {
        isRewound.toggle()
        store.showToast(isRewound ? "已倒带当前筛选结果" : "已恢复正常顺序")
    }

    private func restoreNormalOrder() {
        isRewound = false
        store.showToast("已恢复正常顺序")
    }

    @ViewBuilder
    private var content: some View {
        if showSettings {
            SettingsView(store: store, quitApp: quitApp, restartApp: restartApp)
        } else if showMemoryShore {
            MemoryShoreView(store: store)
        } else if store.filteredSnippets.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(displayedSnippets) { snippet in
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
                    store.loadDemoSnippets()
                } label: {
                    Label("载入示例", systemImage: "sparkles")
                }

                Button {
                    showSettings = true
                } label: {
                    Label("检查设置", systemImage: "gearshape")
                }

                Button {
                    ProjectLinks.open(.gettingStarted)
                } label: {
                    Label("使用指南", systemImage: "questionmark.circle")
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

private struct MemoryShoreView: View {
    @ObservedObject var store: SnippetStore
    @State private var showEmptyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("回忆浅滩")
                        .font(.system(size: 15, weight: .semibold))
                    Text("手动删除或满 7 天的内容会停在这里，直到你恢复或永久删除。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    showEmptyConfirmation = true
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(store.deletedSnippets.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if store.deletedSnippets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("浅滩现在很干净")
                        .font(.system(size: 15, weight: .semibold))
                    Text("删除的内容和过期的 7 天记忆会暂存在这里。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.deletedSnippets) { item in
                            MemoryShoreRow(item: item, store: store)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .confirmationDialog(
            "永久清空回忆浅滩？",
            isPresented: $showEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("永久清空", role: .destructive) {
                store.emptyMemoryShore()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这里的文字、截图、表格和附件将无法恢复。")
        }
    }
}

private struct MemoryShoreRow: View {
    let item: DeletedSnippet
    @ObservedObject var store: SnippetStore
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.snippet.kind == .screenshot ? "photo" : "doc.text")
                    .foregroundStyle(.secondary)
                Text(item.snippet.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    store.restoreFromMemoryShore(item)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("恢复到片段列表")
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("永久删除")
            }

            Text(item.snippet.text.isEmpty ? item.snippet.kind.label : item.snippet.text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text("进入浅滩：\(item.deletedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "永久删除“\(item.snippet.title)”？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("永久删除", role: .destructive) {
                store.permanentlyDelete(item)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。")
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
                    if snippet.supportsRepresentationToggle {
                        IconButton(
                            systemName: snippet.effectiveRepresentation == .image ? "text.viewfinder" : "photo",
                            help: snippet.effectiveRepresentation == .image ? "切换为 OCR 文字" : "切换为图片"
                        ) {
                            store.toggleRepresentation(for: snippet)
                        }
                    }
                    IconButton(systemName: "doc.on.doc", help: "复制") {
                        store.copy(snippet)
                    }
                    IconButton(systemName: "trash", help: "删除", role: .destructive) {
                        store.delete(snippet)
                    }
                }

                SnippetBody(snippet: snippet)

                if let detected = store.detectedDate(for: snippet) {
                    HStack(spacing: 8) {
                        Label(
                            detected.date.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "clock"
                        )
                        .lineLimit(1)
                        Spacer(minLength: 4)
                        IconButton(systemName: "calendar.badge.plus", help: "加入日历") {
                            store.addCalendarEvent(for: snippet)
                        }
                        IconButton(systemName: "alarm", help: "创建闹钟提醒") {
                            store.addAlarmReminder(for: snippet)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                if snippet.isEnriching || !snippet.tags.isEmpty || snippet.enrichmentFailed {
                    SnippetTagFlowLayout(spacing: 6) {
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
                                .lineLimit(1)
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
                    if snippet.attachmentCount > 1 {
                        Label("\(snippet.attachmentCount) 张", systemImage: "square.stack.3d.up")
                    }
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
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            toggleSelection()
        }
        .onChange(of: snippet.title) { newValue in
            title = newValue
        }
        .onChange(of: store.snippets) { _ in
            syncOrderText()
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
    @State private var showImageViewer = false
    @State private var selectedImageIndex = 0

    var body: some View {
        Group {
            if snippet.effectiveRepresentation == .text {
                Text(snippet.text.isEmpty ? "未识别到文字" : snippet.text)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !previewImages.isEmpty {
                ImageGroupPreview(images: previewImages) { index in
                    selectedImageIndex = index
                    showImageViewer = true
                }
                .help(previewImages.count > 1 ? "双击查看 \(previewImages.count) 张大图" : "双击查看大图")
            } else if snippet.kind == .screenshot {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text(snippet.fileName ?? "截图")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showImageViewer) {
            ImageViewer(
                title: snippet.title,
                images: previewImages,
                selectedIndex: $selectedImageIndex
            )
        }
    }

    private var previewImages: [NSImage] {
        if snippet.kind == .screenshot {
            return snippet.allAttachmentPaths.compactMap(NSImage.init(contentsOfFile:))
        }
        if snippet.effectiveRepresentation == .image,
           let image = TextImageRenderer.image(text: snippet.text, title: snippet.title) {
            return [image]
        }
        return []
    }
}

private struct ImageGroupPreview: View {
    let images: [NSImage]
    let onOpen: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { index, image in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 180)
                        .clipped()
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture(count: 2)
                                .onEnded { onOpen(index) }
                        )
                        .accessibilityLabel("第 \(index + 1) 张图片，双击查看大图")
                }
            }
            if images.count > 1 {
                Text("\(images.count) 张")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 180, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.18))
        }
    }
}

private struct ImageViewer: View {
    let title: String
    let images: [NSImage]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var zoomScale: CGFloat = 1

    private var safeIndex: Int {
        guard !images.isEmpty else { return 0 }
        return min(max(selectedIndex, 0), images.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if images.count > 1 {
                    Text("\(safeIndex + 1) / \(images.count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if !images.isEmpty {
                    IconButton(systemName: "minus.magnifyingglass", help: "缩小") {
                        changeZoom(by: -0.25)
                    }
                    .disabled(zoomScale <= 0.25)
                    Text("\(Int((zoomScale * 100).rounded()))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 42)
                    IconButton(systemName: "plus.magnifyingglass", help: "放大") {
                        changeZoom(by: 0.25)
                    }
                    .disabled(zoomScale >= 4)
                    IconButton(systemName: "arrow.counterclockwise", help: "适合窗口") {
                        zoomScale = 1
                    }
                }
                IconButton(systemName: "xmark", help: "关闭大图") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)

            Divider()

            ZStack {
                Color.white

                if images.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                        Text("图片不可用")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                } else {
                    GeometryReader { proxy in
                        let fitted = fittedSize(for: images[safeIndex], in: proxy.size)
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: images[safeIndex])
                                .resizable()
                                .interpolation(.high)
                                .frame(
                                    width: fitted.width * zoomScale,
                                    height: fitted.height * zoomScale
                                )
                                .frame(
                                    minWidth: proxy.size.width,
                                    minHeight: proxy.size.height,
                                    alignment: .center
                                )
                        }
                        .background(Color.white)
                    }
                }

                if images.count > 1 {
                    HStack {
                        viewerArrow(systemName: "chevron.left", help: "上一张", isEnabled: safeIndex > 0) {
                            selectedIndex = safeIndex - 1
                        }
                        Spacer()
                        viewerArrow(systemName: "chevron.right", help: "下一张", isEnabled: safeIndex < images.count - 1) {
                            selectedIndex = safeIndex + 1
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if images.count > 1 {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            Button {
                                selectedIndex = index
                            } label: {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 48)
                                    .clipped()
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5)
                                            .strokeBorder(
                                                index == safeIndex ? Color.accentColor : Color.secondary.opacity(0.2),
                                                lineWidth: index == safeIndex ? 2 : 1
                                            )
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help("查看第 \(index + 1) 张")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 68)
            }
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 520, idealHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedIndex = safeIndex
        }
        .onChange(of: selectedIndex) { _ in
            zoomScale = 1
        }
    }

    private func changeZoom(by amount: CGFloat) {
        withAnimation(.easeOut(duration: 0.12)) {
            zoomScale = min(max(zoomScale + amount, 0.25), 4)
        }
    }

    private func fittedSize(for image: NSImage, in container: CGSize) -> CGSize {
        let availableWidth = max(container.width - 48, 1)
        let availableHeight = max(container.height - 48, 1)
        let imageWidth = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let scale = min(availableWidth / imageWidth, availableHeight / imageHeight)
        return CGSize(width: imageWidth * scale, height: imageHeight * scale)
    }

    @ViewBuilder
    private func viewerArrow(
        systemName: String,
        help: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
    }
}

private struct SnippetTagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let result = arrangement(maxWidth: maxWidth, subviews: subviews)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func arrangement(maxWidth: CGFloat, subviews: Subviews) -> CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: usedWidth, height: y + rowHeight)
    }
}

private struct SettingsView: View {
    @ObservedObject var store: SnippetStore
    let quitApp: () -> Void
    let restartApp: () -> Void
    @State private var showClearLocalDataConfirmation = false

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
                Button {
                    store.copyDiagnostics()
                } label: {
                    Label("复制诊断信息", systemImage: "stethoscope")
                }
            }

            Toggle("监听普通复制", isOn: $store.settings.monitorClipboard)
            Toggle("AI 生成标题和标签", isOn: $store.settings.aiEnrichment)
            Toggle("本地加密持久化保存", isOn: $store.settings.persistSnippets)
            Toggle("开机启动", isOn: $store.settings.launchAtLogin)

            Section("本地备份") {
                Button {
                    store.exportMarkdown()
                } label: {
                    Label("导出当前筛选为 Markdown", systemImage: "doc.plaintext")
                }
                Button {
                    store.exportBackup()
                } label: {
                    Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
                }
                Button {
                    store.importBackup()
                } label: {
                    Label("导入 JSON 备份", systemImage: "square.and.arrow.down")
                }
                Text("备份文件包含片段、设置和附件数据，只保存到你选择的位置，不会上传。API Key 不会导出。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("隐私清理") {
                Button(role: .destructive) {
                    showClearLocalDataConfirmation = true
                } label: {
                    Label("清除本地片段和附件", systemImage: "trash")
                }
                Text("会删除当前片段、组合框内容和本地附件。不会删除 Keychain 中的 API Key，也不会删除你手动导出的备份文件。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("应用控制") {
                Button {
                    restartApp()
                } label: {
                    Label("重启灵感悬浮球", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    quitApp()
                } label: {
                    Label("彻底退出灵感悬浮球", systemImage: "power")
                }
                Text("退出后不是隐藏窗口；需要从“应用程序”重新打开，或等下次登录时自动启动。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("打开窗口快捷键") {
                HStack {
                    Text("当前")
                    Spacer()
                    Text(KeyboardShortcutDefinition.displayName(
                        keyCode: store.settings.hotkeyKeyCode,
                        modifiers: store.settings.hotkeyModifiers
                    ))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    ForEach(ShortcutModifier.allCases) { modifier in
                        Toggle(
                            modifier.symbol,
                            isOn: Binding(
                                get: {
                                    store.settings.hotkeyModifiers & modifier.carbonMask != 0
                                },
                                set: { enabled in
                                    store.setHotkeyModifier(modifier, enabled: enabled)
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .help(modifier.displayName)
                    }
                }

                Picker(
                    "按键",
                    selection: Binding(
                        get: { store.settings.hotkeyKeyCode },
                        set: { store.setHotkeyKeyCode($0) }
                    )
                ) {
                    ForEach(KeyboardShortcutDefinition.supportedKeys) { key in
                        Text(key.label).tag(key.keyCode)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    store.resetHotkey()
                } label: {
                    Label("恢复 Cmd+Shift+C", systemImage: "arrow.counterclockwise")
                }

                Text("修改后立即生效。至少保留一个修饰键；Cmd+C 用于复制，Cmd+Shift+Z 用于收起窗口。")
                    .font(.system(size: 11))
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

            Section("帮助") {
                Button {
                    ProjectLinks.open(.gettingStarted)
                } label: {
                    Label("打开使用指南", systemImage: "book")
                }
                Button {
                    ProjectLinks.open(.faq)
                } label: {
                    Label("查看 FAQ", systemImage: "questionmark.bubble")
                }
                Button {
                    ProjectLinks.open(.issues)
                } label: {
                    Label("反馈问题", systemImage: "exclamationmark.bubble")
                }
                Text("打开的是 GitHub 文档页面；不会上传剪贴板内容。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .confirmationDialog(
            "清除本地片段和附件？",
            isPresented: $showClearLocalDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除本地数据", role: .destructive) {
                store.clearLocalData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除 App 内保存的片段、组合框内容和附件文件。已导出的备份文件和 Keychain API Key 不会被删除。")
        }
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
    @State private var activeDraftSlot: String?
    @State private var showQuickNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(.secondary)
                Text("组合框")
                    .font(.system(size: 12, weight: .semibold))
                Button {
                    showQuickNote.toggle()
                } label: {
                    Label("随笔", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Spacer()
                Button {
                    activeDraftSlot = nil
                    store.polishDraft()
                } label: {
                    if store.isPolishingDraft {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 72)
                    } else {
                        Label("Polish", systemImage: "wand.and.stars")
                            .frame(minWidth: 72)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isPolishingDraft)
                .help("使用 DeepSeek 将积木整理成连贯正文")
                IconButton(systemName: "doc.on.doc", help: "复制组合内容") {
                    store.copyDraftText()
                }
                IconButton(systemName: "xmark.circle", help: "一键取消组合框全部内容") {
                    activeDraftSlot = nil
                    store.clearDraft()
                }
                .disabled(store.draftSnippets.isEmpty && store.draftTextSlots.values.allSatisfy(\.isEmpty))
            }

            if showQuickNote {
                HStack(alignment: .bottom, spacing: 8) {
                    TextEditor(text: $store.quickNoteText)
                        .font(.system(size: 12))
                        .frame(minHeight: 54, maxHeight: 86)
                        .padding(5)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.secondary.opacity(0.2))
                        }
                    VStack(spacing: 6) {
                        Button {
                            store.polishQuickNote()
                        } label: {
                            if store.isPolishingQuickNote {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(minWidth: 72)
                            } else {
                                Label("Polish", systemImage: "wand.and.stars")
                                    .frame(minWidth: 72)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(
                            store.isPolishingQuickNote
                                || store.quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .help("使用同一个 DeepSeek 配置润色随笔")

                        Button {
                            store.saveQuickNote()
                        } label: {
                            Label("形成一条", systemImage: "plus.circle.fill")
                                .frame(minWidth: 72)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(
                            store.isPolishingQuickNote
                                || store.quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
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

            if store.hasCurrentPolishedDraft {
                TextEditor(text: $store.polishedDraftText)
                    .font(.system(size: 12))
                    .frame(minHeight: 64, maxHeight: 100)
                    .padding(6)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(0.28))
                    }
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
                Image(systemName: "text.viewfinder")
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
                        .frame(width: 18, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("在这里插入文字")
                .onHover { hovering in
                    if hovering {
                        NSCursor.iBeam.push()
                    } else {
                        NSCursor.pop()
                    }
                }
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

private struct RewindControl: NSViewRepresentable {
    let isRewound: Bool
    let isEnabled: Bool
    let onToggle: () -> Void
    let onRestore: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageLeading
        button.font = .systemFont(ofSize: 11)
        button.focusRingType = .none
        button.toolTip = "单击切换倒序，双击恢复正常顺序"
        button.setAccessibilityLabel("倒带")
        button.target = context.coordinator
        button.action = #selector(Coordinator.handleClick(_:))
        update(button, coordinator: context.coordinator)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        update(button, coordinator: context.coordinator)
    }

    private func update(_ button: NSButton, coordinator: Coordinator) {
        button.title = "倒带"
        button.image = NSImage(
            systemSymbolName: isRewound ? "backward.end.fill" : "backward.end",
            accessibilityDescription: nil
        )
        button.isEnabled = isEnabled
        coordinator.onToggle = onToggle
        coordinator.onRestore = onRestore
    }

    @MainActor
    final class Coordinator: NSObject {
        var onToggle: (() -> Void)?
        var onRestore: (() -> Void)?
        private var lastClickTime: TimeInterval = 0

        @objc func handleClick(_ sender: NSButton) {
            guard sender.isEnabled else { return }
            let event = NSApp.currentEvent
            let timestamp = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
            let isDoubleClick = (event?.clickCount ?? 0) >= 2
                || timestamp - lastClickTime <= NSEvent.doubleClickInterval

            if isDoubleClick {
                lastClickTime = 0
                onRestore?()
            } else {
                lastClickTime = timestamp
                onToggle?()
            }
        }
    }
}

private enum ProjectLinks {
    case gettingStarted
    case faq
    case issues

    var url: URL {
        switch self {
        case .gettingStarted:
            return URL(string: "https://github.com/IvyCHEN03/clipboard-station/blob/main/docs/GETTING_STARTED.md")!
        case .faq:
            return URL(string: "https://github.com/IvyCHEN03/clipboard-station/blob/main/docs/FAQ.md")!
        case .issues:
            return URL(string: "https://github.com/IvyCHEN03/clipboard-station/issues/new/choose")!
        }
    }

    static func open(_ link: ProjectLinks) {
        NSWorkspace.shared.open(link.url)
    }
}

private func snippetOrderColor(_ index: Int) -> Color {
    let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink]
    return colors[index % colors.count]
}

private func snippetDragProvider(for snippet: Snippet) -> NSItemProvider {
    let provider = NSItemProvider(object: snippet.id.uuidString as NSString)
    guard snippet.kind == .screenshot,
          let attachmentPath = snippet.allAttachmentPaths.first else {
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
