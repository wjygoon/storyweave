import SwiftUI
import SwiftData

// MARK: - Home View
/// Discover screen: hero → recent → recommended worlds → Premium teaser

struct HomeView: View {
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @StateObject private var quota = QuotaManager.shared
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSubscription = false
    @State private var showPaywall = false
    @State private var showCreationEntry = false
    @State private var selectedTemplate: WorldTemplate?
    @State private var selectedStory: Story?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heroSection
                if viewModel.isLoading { loadingSkeleton }
                else if viewModel.hasStories { continueSection }
                recommendedSection
                premiumSection
                CheckInCard()
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ColorPalette.bg.ignoresSafeArea())
        .navigationTitle("StoryWeave")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
ToolbarItem(placement: .topBarTrailing) {
                QuotaRingView { showSubscription = true }
            }
        }
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
        .sheet(isPresented: $showPaywall) {
            PaywallPopup(isPresented: $showPaywall, context: .quotaExhausted)
        }
        .navigationDestination(isPresented: $showCreationEntry) {
            StoryCreationEntryView()
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedTemplate != nil },
            set: { if !$0 { selectedTemplate = nil } }
        )) {
            StoryCreationEntryView(preselectedTemplate: selectedTemplate)
        }
        .navigationDestination(item: $selectedStory) { story in
            StoryReadingView(story: story)
        }
        .task { await viewModel.loadStories() }
        .refreshable { await viewModel.loadStories() }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Quota strip — single, clean, light purple bg, no redundant text
            quotaStrip

            PrimaryButton("开始创作新故事", icon: "wand.and.stars", size: .large) {
                HapticManager.selection()
                showCreationEntry = true
            }
            .frame(height: 56)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var quotaStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorPalette.primary)
            Text(storeKit.isPremium || quota.isPremiumOrTrialActive
                 ? "Premium · 无限创作"
                 : "今日剩余 \(quota.remainingStoryGenerations) 次创作机会")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(ColorPalette.textPrimary)
                .lineLimit(1)
            Spacer()
            Button {
                HapticManager.selection()
                showSubscription = true
            } label: {
                HStack(spacing: 2) {
                    Text("解锁无限")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(ColorPalette.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorPalette.primary.opacity(0.1))
        )
    }

    // MARK: Continue Section

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("继续你的冒险")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(viewModel.stories.prefix(6)) { story in
                        ContinueStoryCard(story: story)
                    .contextMenu {
                        Button(role: .destructive) { HapticManager.warning() }
                            label: { Label("反馈此故事", systemImage: "flag.fill") }
                        Button {
                            if let t = WorldTemplate.template(with: story.worldTemplate) {
                                BlockManager.shared.block(sourceID: t.id)
                            }
                        } label: { Label("屏蔽此世界观", systemImage: "nosign") }
                    }
                            .frame(width: 210)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.selection()
                                selectedStory = story
                            }
                    }
                }
                .padding(.horizontal, Spacing.page)
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    // MARK: Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("继续你的冒险")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Radius.md).fill(ColorPalette.card)
                            .frame(width: 210, height: 120)
                            .shimmering()
                    }
                }
                .padding(.horizontal, Spacing.page)
            }
        }
    }

    // MARK: Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("热门世界观")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 2), spacing: Spacing.sm) {
                ForEach(viewModel.recommendedWorldTemplates.prefix(6)) { template in
                    WorldTemplateCard(template: template) { handleTemplateSelected(template) }
                }
            }
            .padding(.horizontal, Spacing.page)
        }
    }

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "crown.fill").foregroundStyle(ColorPalette.gold)
                Text("Premium 专属").font(Typography.heading()).foregroundStyle(ColorPalette.textStrong)
                Spacer()
                Text("解锁全部").font(Typography.footnote(12)).foregroundStyle(ColorPalette.gold)
            }
            .padding(.horizontal, Spacing.page)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 2), spacing: Spacing.sm) {
                ForEach(viewModel.premiumWorldTemplates.prefix(4)) { template in
                    WorldTemplateCard(template: template, isPremium: true) { handleTemplateSelected(template) }
                }
            }
            .padding(.horizontal, Spacing.page)
        }
    }

    private func handleTemplateSelected(_ template: WorldTemplate) {
        if template.isPremium && !storeKit.isPremium {
            HapticManager.warning()
            showSubscription = true
        } else if viewModel.canCreateNewStory(isPremium: storeKit.isPremium) {
            HapticManager.selection()
            selectedTemplate = template
        } else {
            HapticManager.warning()
            showSubscription = true
        }
    }

}

// MARK: - Continue Story Card

struct ContinueStoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(ColorPalette.primary.opacity(0.12))
                    Image(systemName: "book.fill").font(.system(size: 12)).foregroundStyle(ColorPalette.primary)
                }.frame(width: 28, height: 28)
                Spacer()
                Text("\(Int(story.progress * 100))%")
                    .font(Typography.micro(11))
                    .foregroundStyle(ColorPalette.textTertiary)
            }

            Text(story.displayTitle)
                .font(Typography.bodyMedium(15))
                .foregroundStyle(ColorPalette.textStrong)
                .lineLimit(2)

            ProgressView(value: story.progress).tint(ColorPalette.primary)

            HStack(spacing: Spacing.xxs) {
                Text(WorldTemplate.template(with: story.worldTemplate)?.emoji ?? "📖")
                Text(WorldTemplate.template(with: story.worldTemplate)?.name ?? "未知")
                    .font(Typography.footnote(11))
                    .foregroundStyle(ColorPalette.textSecondary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(ColorPalette.card)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 3)
        )
        .onAppear {
            // 修复历史空标题数据
            if story.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                story.title = story.displayTitle
            }
        }
    }
}

// MARK: - World Template Card

struct WorldTemplateCard: View {
    let template: WorldTemplate
    var isPremium: Bool = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color(hex: template.previewColor).opacity(0.18))
                    Text(template.emoji).font(.system(size: 36))
                }
                .frame(height: 78)

                Text(template.name)
                    .font(Typography.caption(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorPalette.textStrong)
                    .lineLimit(1)

                Text(template.subtitle)
                    .font(Typography.footnote(11))
                    .foregroundStyle(ColorPalette.textSecondary)
                    .lineLimit(1)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(ColorPalette.card)
                    .shadow(color: .black.opacity(pressed ? 0.1 : 0.04), radius: pressed ? 12 : 6, x: 0, y: pressed ? 4 : 2)
            )
            .overlay(alignment: .topTrailing) {
                if isPremium {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorPalette.gold)
                        .padding(6)
                        .background(Circle().fill(ColorPalette.gold.opacity(0.15)))
                        .padding(Spacing.xxs)
                }
            }
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: pressed)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false })
    }
}

// MARK: - Empty State (⑤)

struct HomeEmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(ColorPalette.immersiveDarkAccent)
                .padding(.bottom, 8)

            Text("还没有故事")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(ColorPalette.textStrong)

            Text("选择一个世界观，让 AI 为你编织第一个故事")
                .font(.system(size: 14))
                .foregroundStyle(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onCreate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开始创作")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(ColorPalette.immersiveDarkBG)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(Capsule().fill(ColorPalette.immersiveDarkAccent))
                .shadow(color: ColorPalette.immersiveDarkAccent.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.bg.opacity(0.95))
        .ignoresSafeArea()
    }
}
