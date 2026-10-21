import SwiftUI

// MARK: - Story Creation Entry
/// Two-mode story creation: Quick (template-driven) or Custom (free-form).

struct StoryCreationEntryView: View {
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @StateObject private var quota = QuotaManager.shared
    @StateObject private var viewModel: StoryCreationViewModel
    @State private var showPaywall = false

    init(preselectedTemplate: WorldTemplate? = nil) {
        let vm = StoryCreationViewModel()
        vm.selectedWorldTemplate = preselectedTemplate
        if preselectedTemplate != nil { vm.mode = .quick }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.section) {
                headerSection
                worldTemplateSelection
                characterSection
                styleSection
                generateButton
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ColorPalette.bg.ignoresSafeArea())
        .navigationTitle("创作故事")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { viewModel.isGenerating },
            set: { if !$0 { viewModel.isGenerating = false } }
        )) {
            LoadingOverlay(message: "AI 正在构思故事...").presentationBackground(.clear)
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.generatedOpening != nil && viewModel.createdStory == nil },
            set: { if !$0 { viewModel.generatedOpening = nil } }
        )) {
            GeneratedOpeningReviewView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.createdStory != nil },
            set: { if !$0 { viewModel.createdStory = nil } }
        )) {
            if let story = viewModel.createdStory { StoryReadingView(story: story) }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("让 AI 为你编织故事")
                .font(Typography.title(26))
                .foregroundStyle(ColorPalette.textStrong)
            Text("选世界观、填角色信息、一键生成独一无二的开篇")
                .font(Typography.body(15))
                .foregroundStyle(ColorPalette.textSecondary)
        }
        .padding(.horizontal, Spacing.page)
        .padding(.top, Spacing.sm)
    }

    // MARK: Mode

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("创作模式").font(Typography.heading()).foregroundStyle(ColorPalette.textStrong)
            HStack(spacing: Spacing.sm) {
                modeCard(title: "快速开局", icon: "bolt.fill", subtitle: "选模板 + 角色，一键生成", mode: .quick)
                modeCard(title: "自定义", icon: "pencil.and.outline", subtitle: "自由设定世界观和开端", mode: .custom)
            }
        }
        .padding(.horizontal, Spacing.page)
    }

    private func modeCard(title: String, icon: String, subtitle: String, mode: StoryCreationViewModel.CreationMode) -> some View {
        let selected = viewModel.mode == mode
        return Button { HapticManager.selection(); viewModel.mode = mode } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(selected ? .white : ColorPalette.primary)
                Text(title).font(Typography.caption(14)).fontWeight(.semibold)
                Text(subtitle).font(Typography.footnote(11)).foregroundStyle(selected ? .white.opacity(0.75) : ColorPalette.textSecondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(selected ? AnyShapeStyle(ColorPalette.brandGradient) : AnyShapeStyle(ColorPalette.card))
            )
            .shadow(color: selected ? ColorPalette.primary.opacity(0.3) : .black.opacity(0.04), radius: selected ? 12 : 6, x: 0, y: selected ? 4 : 2)
        }.buttonStyle(.plain)
    }

    // MARK: World Template

    private var worldTemplateSelection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("选择世界观").font(Typography.heading()).foregroundStyle(ColorPalette.textStrong)

            // Premium section ON TOP
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(WorldTemplate.all.filter { $0.isPremium }) { t in
                        premiumTemplateChip(t)
                    }
                }
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(ColorPalette.gold.opacity(0.06)))
            }

            // Free section
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(WorldTemplate.all.filter { !$0.isPremium }) { t in
                        templateChip(t)
                    }
                }
            }

            if let selected = viewModel.selectedWorldTemplate {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(selected.emoji)
                        Text(selected.name).fontWeight(.semibold).font(Typography.caption(13))
                        if selected.isPremium && !storeKit.isPremium { Image(systemName: "crown.fill").foregroundStyle(ColorPalette.gold).font(.system(size: 10)) }
                        Spacer()
                        Button { viewModel.selectedWorldTemplate = nil; viewModel.customWorldSetting = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(ColorPalette.textTertiary).font(.system(size: 14)) }
                    }
                    Text(selected.description).font(Typography.footnote(12)).foregroundStyle(ColorPalette.textSecondary)
                }
                .padding(Spacing.sm).background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(ColorPalette.primary.opacity(0.06)))

                // 可选覆盖：自定义世界观
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text("自定义世界观（可选覆盖模板设定）").font(Typography.footnote(12)).foregroundStyle(ColorPalette.textSecondary)
                        Spacer()
                        if !viewModel.customWorldSetting.isEmpty {
                            Button { viewModel.customWorldSetting = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(ColorPalette.textTertiary).font(.system(size: 12)) }
                        }
                    }
                    TextField("留空则使用模板默认设定，填写则完全覆盖...", text: $viewModel.customWorldSetting, axis: .vertical)
                        .font(Typography.body())
                        .foregroundStyle(ColorPalette.textStrong)
                        .tint(ColorPalette.primary)
                        .padding(Spacing.md).frame(minHeight: 60)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(ColorPalette.card)
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(ColorPalette.hairline, lineWidth: 1))
                        )
                }
            }
        }
        .padding(.horizontal, Spacing.page)
    }

    private func templateChip(_ t: WorldTemplate) -> some View {
        let selected = viewModel.selectedWorldTemplate?.id == t.id
        return Button {
            HapticManager.selection()
            viewModel.selectedWorldTemplate = t
        } label: {
            HStack(spacing: 6) {
                Text(t.emoji)
                Text(t.name).font(Typography.caption(13))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(selected ? ColorPalette.primary : ColorPalette.card).overlay(Capsule().stroke(selected ? ColorPalette.primary : ColorPalette.hairline)))
            .foregroundStyle(selected ? .white : ColorPalette.textPrimary)
        }.buttonStyle(.plain)
    }

    private func premiumTemplateChip(_ t: WorldTemplate) -> some View {
        let selected = viewModel.selectedWorldTemplate?.id == t.id
        let locked = !storeKit.isPremium && !quota.isPremiumOrTrialActive
        return Button {
            HapticManager.selection()
            if locked {
                HapticManager.warning()
                showPaywall = true
            } else {
                viewModel.selectedWorldTemplate = t
            }
        } label: {
            HStack(spacing: 6) {
                Text(t.emoji)
                Text(t.name).font(Typography.caption(13)).fontWeight(.semibold)
                Text("限定").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(ColorPalette.gold))
                if locked { Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(ColorPalette.gold) }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(selected ? AnyShapeStyle(ColorPalette.goldGradient) : AnyShapeStyle(ColorPalette.gold.opacity(0.1))).overlay(Capsule().stroke(selected ? ColorPalette.gold : ColorPalette.gold.opacity(0.3))))
            .foregroundStyle(selected ? .white : (locked ? ColorPalette.textTertiary : ColorPalette.gold))
        }.buttonStyle(.plain)
    }

    // MARK: Character

    @State private var showCharacterPicker = false

    private var characterSection: some View {
        let existingCharacters = (try? DataManager.shared.fetchAllCharacters()) ?? []
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("主角角色").font(Typography.heading()).foregroundStyle(ColorPalette.textStrong)
                Spacer()
                if !existingCharacters.isEmpty {
                    Button {
                        HapticManager.selection()
                        showCharacterPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.text.rectangle").font(.system(size: 12))
                            Text("从角色库选").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(ColorPalette.primary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(ColorPalette.primary.opacity(0.1)))
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                characterField(label: "角色名称", placeholder: "给角色起个名字", text: $viewModel.protagonistName, focus: .protagonistName)
                characterField(label: "性格特点", placeholder: "如：勇敢、善良、聪明、倔强...", text: $viewModel.protagonistPersonality, multiLine: true, focus: .personality)
            }
        }
        .padding(.horizontal, Spacing.page)
        .sheet(isPresented: $showCharacterPicker) {
            CharacterPickerSheet(characters: existingCharacters) { selected in
                viewModel.protagonistName = selected.name
                viewModel.protagonistPersonality = selected.personality
                viewModel.addCharacter(name: selected.name, personality: selected.personality)
                hideKeyboard()
            }
        }
    }

    @FocusState private var focusedField: FieldFocus?

    private enum FieldFocus { case protagonistName, personality }

    private func characterField(label: String, placeholder: String, text: Binding<String>, multiLine: Bool = false, focus: FieldFocus? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(Typography.footnote(12)).foregroundStyle(ColorPalette.textSecondary)
            Group {
                if multiLine {
                    TextField(placeholder, text: text, axis: .vertical)
                        .submitLabel(.done)
                } else {
                    TextField(placeholder, text: text)
                        .submitLabel(.done)
                }
            }
            .font(Typography.body())
            .foregroundStyle(ColorPalette.textStrong)
            .tint(ColorPalette.primary)
            .padding(Spacing.md)
            .frame(minHeight: multiLine ? 50 : nil)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(ColorPalette.card)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(ColorPalette.hairline, lineWidth: 1))
            )
            .focused($focusedField, equals: focus)
            .onSubmit {
                focusedField = nil
                hideKeyboard()
            }
        }
    }
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Style

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("故事风格").font(Typography.heading()).foregroundStyle(ColorPalette.textStrong)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(StoryStyle.allCases) { style in
                        styleChip(style)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.page)
    }

    private func styleChip(_ style: StoryStyle) -> some View {
        let selected = viewModel.selectedStyle == style
        return Button { HapticManager.selection(); viewModel.selectedStyle = style } label: {
            Text(style.displayName).font(Typography.caption(13)).padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(selected ? AnyShapeStyle(ColorPalette.primary) : AnyShapeStyle(ColorPalette.card)).overlay(Capsule().stroke(selected ? ColorPalette.primary : ColorPalette.hairline)))
                .foregroundStyle(selected ? .white : ColorPalette.textPrimary)
        }.buttonStyle(.plain)
    }

    // MARK: Generate

    private var generateButton: some View {
        VStack(spacing: Spacing.md) {
            if let error = viewModel.errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorPalette.error)
                    Text(error).font(Typography.footnote(12)).foregroundStyle(ColorPalette.error).lineLimit(2)
                    Spacer()
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(ColorPalette.error.opacity(0.1)))
            }

            generateStoryButton
        }
        .padding(.horizontal, Spacing.page)
    }
    private var generateStoryButton: some View {
        let hasQuota = storeKit.isPremium || quota.isPremiumOrTrialActive || quota.remainingStoryGenerations > 0
        let disabled = !viewModel.canGenerate || (!hasQuota && !storeKit.isPremium && !quota.isPremiumOrTrialActive)
        
        return PrimaryButton(
            storeKit.isPremium || quota.isPremiumOrTrialActive ? "生成故事开篇" : (hasQuota ? "生成故事开篇 (今日 \(quota.remainingStoryGenerations))" : "额度不足，开通会员无限生成"),
            icon: "wand.and.stars",
            size: .large,
            tint: (hasQuota || storeKit.isPremium || quota.isPremiumOrTrialActive) ? .primary : .gray,
            isLoading: viewModel.isGenerating,
            isDisabled: disabled
        ) {
            if !hasQuota && !storeKit.isPremium && !quota.isPremiumOrTrialActive {
                showPaywall = true
            } else {
                Task {
                    if !storeKit.isPremium && !quota.isPremiumOrTrialActive {
                        _ = quota.consumeStoryGeneration()
                    }
                    await viewModel.generateOpening()
                }
            }
        }
    }
}

// MARK: - Generated Opening Review

struct GeneratedOpeningReviewView: View {
    @ObservedObject var viewModel: StoryCreationViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles").foregroundStyle(ColorPalette.primary)
                    Text("AI 生成的故事开篇").font(Typography.heading()).foregroundStyle(ColorPalette.primary)
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(viewModel.generatedOpening ?? "")
                        .font(Typography.reading(18))
                        .foregroundStyle(ColorPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(6)

                    Divider().padding(.vertical, Spacing.xs)

                    if let sceneDesc = viewModel.generatedSceneDescription {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "photo").foregroundStyle(ColorPalette.textSecondary)
                            Text("场景：\(sceneDesc)").font(Typography.footnote(12)).foregroundStyle(ColorPalette.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("故事将有以下选择分支").font(Typography.caption(13)).foregroundStyle(ColorPalette.textSecondary)
                        ForEach(viewModel.generatedChoices) { choice in
                            HStack(spacing: Spacing.xs) {
                                Circle().fill(ColorPalette.primary).frame(width: 5, height: 5)
                                Text(choice.text).font(Typography.body(15)).foregroundStyle(ColorPalette.textPrimary).lineLimit(2)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(ColorPalette.primary.opacity(0.05)))
                }
                .padding(Spacing.lg)
                .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(ColorPalette.card).shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4))

                VStack(spacing: Spacing.sm) {
                    PrimaryButton("确认创建故事", icon: "checkmark") {
                        Task { await viewModel.confirmCreation() }
                    }
                    SecondaryButton("重新生成", icon: "arrow.clockwise") {
                        Task { await viewModel.generateOpening() }
                    }
                }
            }
            .padding(.horizontal, Spacing.page).padding(.vertical, Spacing.sm)
        }
        .background(ColorPalette.bg.ignoresSafeArea())
        .navigationTitle("预览").navigationBarTitleDisplayMode(.inline)
    }
}
