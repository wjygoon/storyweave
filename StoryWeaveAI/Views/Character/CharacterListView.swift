import SwiftUI
import SwiftData

// MARK: - Character List View

struct CharacterListView: View {
    
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @Query(sort: \Character.updatedAt, order: .reverse) private var characters: [Character]
    @State private var showCreateSheet = false
    @State private var selectedCharacter: Character?
    @State private var showSaveToast = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                characterGrid
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .navigationTitle("角色")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.selection()
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSaveToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text("角色已添加").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 80)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSaveToast)
        .sheet(isPresented: $showCreateSheet) {
            CharacterCreateSheet {
                // 等 sheet 关闭动画结束再弹 toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showSaveToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        showSaveToast = false
                    }
                }
            }
        }
        .sheet(item: $selectedCharacter) { character in
            CharacterDetailView(character: character)
        }
        .background(ColorPalette.bg.ignoresSafeArea())
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("管理你的角色")
                .font(Typography.title())
            
            Text("在故事中创建或选择角色，让你的冒险更有代入感")
                .font(Typography.body(15))
                .foregroundStyle(ColorPalette.textSecondary)
        }
    }
    
    @ViewBuilder
    private var characterGrid: some View {
        if characters.isEmpty {
            EmptyStateView(
                icon: "person.crop.circle.badge.plus",
                title: "还没有角色",
                message: "创建独特的角色，让你的故事更精彩",
                actionTitle: "创建角色"
            ) {
                showCreateSheet = true
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(characters) { character in
                    CharacterCard(character: character) {
                        selectedCharacter = character
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.85))
                    ))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: characters.count)
        }
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let character: Character
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                // 头像
                ZStack {
                    Circle()
                        .fill(ColorPalette.primary.opacity(0.1))
                        .frame(width: 72, height: 72)
                    
                    if let avatarURL = character.avatarURL {
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image.resizable().clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(ColorPalette.primary)
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorPalette.primary)
                    }
                    
                    if character.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorPalette.gold)
                            .offset(x: 24, y: -24)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(character.name)
                        .font(Typography.caption(15))
                        .fontWeight(.semibold)
                    
                    Text(character.personality)
                        .font(Typography.footnote(12))
                        .foregroundStyle(ColorPalette.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorPalette.lightCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Character Create Sheet

struct CharacterCreateSheet: View {

    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var personality: String = ""
    @State private var appearance: String = ""
    @State private var skills: String = ""
    @State private var background: String = ""
    @State private var isAIHintLoading = false
    @State private var aiHintResult: CharacterDetails?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 头像占位
                    ZStack {
                        Circle()
                            .fill(ColorPalette.primary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(ColorPalette.primary)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(ColorPalette.primary))
                            .offset(x: 28, y: 28)
                    }
                    .padding(.top, 20)
                    
                    inputField("角色名称", placeholder: "如：李明、艾莉丝...", text: $name)
                    inputField("性格特点", placeholder: "如：勇敢、温柔、机智...", text: $personality)
                    inputField("外貌描述（可选）", placeholder: "如：黑色短发，戴眼镜...", text: $appearance)
                    inputField("擅长技能（可选）", placeholder: "如：剑术、医术、编程...", text: $skills)
                    inputField("背景故事（可选）", placeholder: "简短介绍角色的过去...", text: $background, axis: .vertical)
                }
                .padding()
            }
            .navigationTitle("创建角色")
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveCharacter()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func inputField(_ label: String, placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typography.footnote(12))
                .foregroundStyle(ColorPalette.textSecondary)
            
            Group {
                if axis == .vertical {
                    TextField(placeholder, text: text, axis: .vertical)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .submitLabel(.done)
            .font(Typography.body())
            .foregroundStyle(ColorPalette.textStrong)
            .tint(ColorPalette.primary)
            .frame(minHeight: axis == .vertical ? 80 : nil)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorPalette.card)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ColorPalette.hairline, lineWidth: 1))
            )
            .onSubmit {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func saveCharacter() {
        let char = Character(
            name: name.trimmingCharacters(in: .whitespaces),
            personality: personality.isEmpty ? "神秘" : personality,
            appearance: appearance.isEmpty ? nil : appearance,
            skills: skills.isEmpty ? nil : skills,
            background: background.isEmpty ? nil : background
        )
        
        Task { @MainActor in
            DataManager.shared.createCharacter(char)
            HapticManager.success()
            dismiss()
            onSaved()
        }
    }
}

// MARK: - Character Detail

struct CharacterDetailView: View {
    
    let character: Character
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 大头像
                    ZStack {
                        Circle()
                            .fill(ColorPalette.primary.opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(ColorPalette.primary)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text(character.name)
                            .font(Typography.title())
                        
                        Text(character.personality)
                            .font(Typography.body(15))
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                    
                    // 详细信息卡片
                    VStack(alignment: .leading, spacing: 16) {
                        if let appearance = character.appearance {
                            detailRow(icon: "eye.fill", title: "外貌", content: appearance)
                        }
                        if let skills = character.skills {
                            detailRow(icon: "bolt.fill", title: "技能", content: skills)
                        }
                        if let background = character.background {
                            detailRow(icon: "book.fill", title: "背景", content: background)
                        }
                        
                        HStack {
                            Label("参与 \(character.stories.count) 个故事", systemImage: "book.closed")
                                .font(Typography.footnote(12))
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ColorPalette.lightCardBackground)
                    )
                }
                .padding()
            }
            .navigationTitle("角色详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            character.isFavorite.toggle()
                        } label: {
                            Label(character.isFavorite ? "取消收藏" : "收藏", systemImage: character.isFavorite ? "star.slash" : "star")
                        }
                        
                        Button(role: .destructive) {
                            deleteCharacter()
                        } label: {
                            Label("删除角色", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailRow(icon: String, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorPalette.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.footnote(12))
                    .foregroundStyle(ColorPalette.textSecondary)
                Text(content)
                    .font(Typography.body(15))
                    .foregroundStyle(ColorPalette.textPrimary)
            }
        }
    }
    
    private func deleteCharacter() {
        modelContext.delete(character)
        dismiss()
    }
}

// MARK: - Character Picker Sheet (for story creation)

struct CharacterPickerSheet: View {
    let characters: [Character]
    let onPick: (Character) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if characters.isEmpty {
                    EmptyStateView(
                        icon: "person.2.slash",
                        title: "角色库为空",
                        message: "先在角色 Tab 创建一些角色吧"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(characters) { char in
                                Button {
                                    HapticManager.selection()
                                    onPick(char)
                                    dismiss()
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        ZStack {
                                            Circle().fill(ColorPalette.primary.opacity(0.15)).frame(width: 40, height: 40)
                                            Text(String(char.name.prefix(1)))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(ColorPalette.primary)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(char.name).font(Typography.body(15)).foregroundStyle(ColorPalette.textStrong)
                                            Text(char.personality).font(Typography.footnote(12)).foregroundStyle(ColorPalette.textSecondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ColorPalette.textTertiary)
                                    }
                                    .padding(Spacing.md)
                                    .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(ColorPalette.card))
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("选择角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
