import SwiftUI

// MARK: - Story Reading View
/// Core interactive reader: serif typewriter text + branch choices + scene illustration.

struct StoryReadingView: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared

    @StateObject private var viewModel = StoryReadingViewModel()
    @State private var showSettings = false
    @State private var showTimeline = false
    @State private var showShare = false
    @State private var textSize: CGFloat = 18
    @State private var readingMode: ReadingMode = .paper
    @State private var isTypingComplete = false
    @State private var selectedChoiceID: String? = nil
    @State private var showSceneTransition = false
    @State private var followTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            readingBackground

            VStack(spacing: 0) {
                topBar
                mainContent
                bottomProgressBar
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.loadStory(story) }
        .sheet(isPresented: $showSettings) {
            ReadingSettingsSheet(textSize: $textSize, mode: $readingMode)
        }
        .sheet(isPresented: $showTimeline) { TimelineSheet(viewModel: viewModel) }
        .sheet(isPresented: $showShare) {
            if let s = viewModel.story { ShareCardView(story: s) }
        }
        .overlay {
            // ⑦ 黑场场景切换
            if showSceneTransition {
                Color.black
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
            if viewModel.isGenerating {
                LoadingOverlay(message: "AI 正在续写故事...")
                    .transition(.opacity)
            }
            if let error = viewModel.generationError {
                ErrorBanner(message: error) { viewModel.generationError = nil } onRetry: {
                    viewModel.generationError = nil
                    if let last = viewModel.lastChoice {
                        Task { await viewModel.makeChoice(last) }
                    }
                }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Background

    private var readingBackground: some View {
        readingMode.background.ignoresSafeArea()
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: Spacing.xs) {
            iconButton("chevron.left") { dismiss() }
            Spacer()
            iconButton("arrow.triangle.branchpath") { showTimeline = true }
            iconButton("square.and.arrow.up") { showShare = true }
            iconButton("textformat.size") { showSettings = true }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.top, Spacing.xxs)
    }

    private func iconButton(_ systemName: String, _ action: @escaping () -> Void) -> some View {
        Button { HapticManager.selection(); action() } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(readingMode.textColor)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: Main Content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    headerCard
                    contentSection(proxy: proxy)
                    imageActionSection
                    choicesSection
                    bottomSpacer
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(WorldTemplate.template(with: story.worldTemplate)?.emoji ?? "📖")
                    .font(.system(size: 20))
                Text(story.displayTitle)
                    .font(Typography.heading())
                    .foregroundStyle(readingMode.textColor)
            }
            HStack(spacing: Spacing.sm) {
                Text(WorldTemplate.template(with: story.worldTemplate)?.name ?? story.worldTemplate)
                    .font(Typography.footnote(12))
                    .foregroundStyle(ColorPalette.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(ColorPalette.primary.opacity(0.12)))
                Text(story.storyStyle.displayName)
                    .font(Typography.footnote(12))
                    .foregroundStyle(readingMode.mutedColor)
            }
        }
    }

    private func contentSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let current = viewModel.currentNode {
                TypewriterText(text: current.content, isComplete: $isTypingComplete) {
                    scheduleFollowScroll(proxy: proxy, anchorID: current.id)
                }
                .font(Typography.reading(textSize))
                .foregroundStyle(readingMode.textColor)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .id(current.id)
                .contextMenu {
                    Button(role: .destructive) { HapticManager.warning() }
                        label: { Label("反馈此节点", systemImage: "flag.fill") }
                }
                .onChange(of: current.content) { _, _ in
                    scheduleFollowScroll(proxy: proxy, anchorID: current.id, delay: 0.2)
                }
                .onChange(of: isTypingComplete) { _, complete in
                    if complete {
                        // 读完即标记当前节点已读
                        viewModel.currentNode?.isRead = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("choices-top", anchor: .top)
                            }
                        }
                    }
                }

                HStack { Spacer(); AIGeneratedBadge(compact: true) }
            } else {
                ProgressView()
                    .tint(readingMode.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            }
        }
    }

    /// 防抖跟随滚动：打字过程中每 3 字触发一次，0.12s 内合并，始终把最新文字留在屏幕内
    private func scheduleFollowScroll(proxy: ScrollViewProxy, anchorID: UUID, delay: Double = 0.12) {
        followTask?.cancel()
        followTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.linear(duration: 0.15)) { proxy.scrollTo(anchorID, anchor: .bottom) }
            }
        }
    }

    // MARK: - 插图（有图时才显示，完全不占无图空间）
    @ViewBuilder
    private var sceneImageSection: some View {
        if let data = viewModel.sceneImageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.top, Spacing.sm)
        }
    }

    // MARK: - 插图操作区（无图时显示按钮，有图时显示图片）
    @ViewBuilder
    private var imageActionSection: some View {
        if viewModel.sceneImageData != nil {
            sceneImageSection
        } else {
            Button {
                Task { await viewModel.generateSceneImage() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if viewModel.isGeneratingImage {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("正在生成插图...")
                            .font(Typography.footnote(13))
                            .foregroundStyle(readingMode.mutedColor)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .medium))
                        Text("生成场景插图")
                            .font(Typography.footnote(13))
                    }
                }
                .foregroundStyle(ColorPalette.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(ColorPalette.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .stroke(ColorPalette.primary.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isGeneratingImage || viewModel.isGenerating)
        }
    }

    @ViewBuilder
    private var choicesSection: some View {
        if let current = viewModel.currentNode,
               !current.choices.isEmpty,
               isTypingComplete,
               current.isCurrent {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Rectangle()
                        .fill(readingMode.mutedColor.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.vertical, Spacing.xs)
                    HStack {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 12)).foregroundStyle(ColorPalette.primary)
                        Text("做出你的选择").font(Typography.caption(13)).foregroundStyle(ColorPalette.primary)
                        Spacer()
                    }
                    .id("choices-top")
                    Text("你会怎么做？")
                        .font(Typography.caption(13))
                        .foregroundStyle(readingMode.mutedColor)
                        .padding(.leading, Spacing.xs)
                    ForEach(current.choices) { choice in
                        ChoiceButton(
                            choice: choice,
                            isSelected: selectedChoiceID == choice.id,
                            isLoading: viewModel.isGenerating,
                            surfaceColor: readingMode.surfaceColor,
                            primaryTextColor: readingMode.textColor,
                            secondaryTextColor: readingMode.mutedColor
                        ) {
                            // ④ 连贯动画: 选中→回弹→淡出→流式续写
                            HapticManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedChoiceID = choice.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    selectedChoiceID = nil
                                }
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                showSceneTransition = true
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                await viewModel.makeChoice(choice)
                                showSceneTransition = false
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: current.id)
            }
        }
    private var bottomProgressBar: some View {
        HStack {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "clock").font(.system(size: 12))
                Text(viewModel.progressText).font(Typography.footnote(11))
            }
            .foregroundStyle(readingMode.mutedColor)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        .background(
            LinearGradient(
                colors: [readingMode.background.opacity(0), readingMode.background],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var bottomSpacer: some View {
        Color.clear.frame(height: 0)
    }

}
// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorPalette.error)
                Text(message).font(Typography.caption(13)).foregroundStyle(ColorPalette.textPrimary).lineLimit(2)
                Spacer()
                Button(action: onRetry) {
                    Label("重 roll", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorPalette.error)
                }
                .buttonStyle(.plain)
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(ColorPalette.textSecondary) }
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(ColorPalette.cardElevated)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(ColorPalette.error.opacity(0.45), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            )
            .padding(.horizontal, Spacing.page).padding(.top, Spacing.xl)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Reading Settings Sheet

struct ReadingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var textSize: CGFloat
    @Binding var mode: ReadingMode

    var body: some View {
        NavigationStack {
            Form {
                Section("阅读背景") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(ReadingMode.allCases) { m in
                                Button { HapticManager.selection(); mode = m } label: {
                                    VStack(spacing: Spacing.xs) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(m.background).frame(width: 52, height: 52)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(mode == m ? ColorPalette.primary : ColorPalette.hairline, lineWidth: mode == m ? 2 : 1))
                                        Text(m.displayName).font(Typography.footnote(12)).foregroundStyle(ColorPalette.textPrimary)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("字体大小") {
                    HStack(spacing: Spacing.sm) {
                        ForEach(ReadingFontSize.allCases) { size in
                            Button { HapticManager.selection(); textSize = size.rawValue } label: {
                                Text(size.displayName).font(.system(size: 14))
                                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                                    .background(RoundedRectangle(cornerRadius: Radius.sm).fill(textSize == size.rawValue ? ColorPalette.primary : ColorPalette.card))
                                    .foregroundStyle(textSize == size.rawValue ? .white : ColorPalette.textPrimary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Button { textSize = 18; mode = .paper } label: {
                        HStack { Spacer(); Text("恢复默认") .foregroundStyle(ColorPalette.error); Spacer() }
                    }
                }
            }
            .navigationTitle("阅读设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Timeline Sheet

struct TimelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StoryReadingViewModel

    var body: some View {
        NavigationStack {
            Group {
                let nodes = viewModel.nodes
                if nodes.isEmpty {
                    EmptyStateView(icon: "book.closed", title: "暂无故事节点", message: "继续阅读来创建更多剧情分支")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                                ForEach(nodes) { node in
                                    timelineRow(for: node).id(node.id)
                                }
                            }.padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                            .onAppear {
                                if let current = viewModel.currentNode {
                                    proxy.scrollTo(current.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("故事时间线").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large, .medium])
    }

    @ViewBuilder
    private func timelineRow(for node: StoryNode) -> some View {
        let isCurrent = node.isCurrent
        let num = node.sequence + 1

        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? ColorPalette.primary : (node.isRead ? ColorPalette.textSecondary : ColorPalette.card))
                        .overlay(Circle().stroke(ColorPalette.hairline, lineWidth: 1))
                        .frame(width: isCurrent ? 30 : 22)
                    if isCurrent {
                        Image(systemName: "play.fill").font(.system(size: 10)).foregroundStyle(.white)
                    } else {
                        Text("\(num)").font(Typography.micro(10)).fontWeight(.bold).foregroundStyle(isCurrent ? .white : (node.isRead ? .white : ColorPalette.textSecondary))
                    }
                }
                if viewModel.nodes.last?.id != node.id {
                    Rectangle().fill(ColorPalette.primary.opacity(isCurrent ? 0.5 : 0.15)).frame(width: 2).frame(maxHeight: .infinity).padding(.vertical, 2)
                }
            }.frame(width: 30)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(node.content.prefix(80) + (node.content.count > 80 ? "..." : ""))
                    .font(Typography.body(14))
                    .foregroundStyle(isCurrent ? ColorPalette.textStrong : ColorPalette.textSecondary).lineLimit(2)
                if node.selectedChoiceId != nil {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "arrow.right").font(.system(size: 10))
                        Text("已选择分支").font(Typography.micro(11))
                    }.foregroundStyle(ColorPalette.primary)
                }
            }
            .padding(.vertical, Spacing.xs).padding(.horizontal, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(isCurrent ? ColorPalette.primary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.medium()
                Task { await viewModel.rewindTo(node: node) }
                dismiss()
            }
        }
    }
}
