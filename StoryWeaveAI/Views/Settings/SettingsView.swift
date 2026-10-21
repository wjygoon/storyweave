import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @StateObject private var authManager: AuthManager = AuthManager.shared
    @StateObject private var prefs = UserPreferences.shared
    
    @State private var activeSheet: SettingsSheet?
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showDeleteAccountConfirm = false

    /// 同一视图上挂多个 .sheet(isPresented:) 在 iOS 上可能出现弹出后立即消失，
    /// 改为单一 item 驱动的 sheet
    enum SettingsSheet: String, Identifiable {
        case subscription, teenMode, reportForm
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileSection
                subscriptionSection
                readingSection
                teenModeSection
                dataSection
                privacySection
                aboutSection
            }
            .padding(.vertical, 12)
        }
        .background(ColorPalette.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .subscription: SubscriptionView()
            case .teenMode: TeenModeSettingsView()
            case .reportForm: FeedbackFormView(source: "settings")
            }
        }
        .alert("永久删除账号？", isPresented: $showDeleteAccountConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                Task {
                    try? await authManager.deleteAccount()
                }
            }
        } message: {
            Text("此操作不可撤销，将删除本地与云端的全部故事、角色与人生档案数据。")
        }
    }
    
    // MARK: Profile Section
    
    private var profileSection: some View {
        VStack {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ColorPalette.primary.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorPalette.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let user = authManager.currentUser {
                        Text(user.name)
                            .font(Typography.subtitle(18))
                        Text(user.email ?? "Apple 用户")
                            .font(Typography.footnote(12))
                            .foregroundStyle(ColorPalette.textSecondary)
                    } else {
                        Text("未登录")
                            .font(Typography.subtitle(18))
                        Button {
                            authManager.signInWithApple()
                        } label: {
                            Label("使用 Apple 登录", systemImage: "apple.logo")
                                .font(Typography.caption(13))
                                .foregroundStyle(ColorPalette.primary)
                        }
                    }
                }
                
                Spacer()
                
                if authManager.currentUser != nil {
                    Button {
                        HapticManager.medium()
                        authManager.signOut()
                    } label: {
                        Text("退出")
                            .font(Typography.footnote(12))
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorPalette.lightCardBackground)
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: Subscription Section
    
    private var subscriptionSection: some View {
        section(header: "会员") {
            settingsRow(icon: "crown.fill", title: storeKit.isPremium ? "Premium 会员" : "升级 Premium", subtitle: storeKit.isPremium ? "享受全部权益" : "解锁无限创作") {
                activeSheet = .subscription
            }
            
            settingsRow(icon: "bag.fill", title: "内购道具", subtitle: "限定角色、剧情卡等") {
                // TODO: 内购道具商店
            }
        }
    }
    
    // MARK: Reading Section
    
    private var readingSection: some View {
        section(header: "阅读体验") {
            themeMenuRow

            ToggleRow(icon: "sparkles", title: "打字机效果", isOn: Binding(
                get: { prefs.enableTypewriterEffect },
                set: { prefs.enableTypewriterEffect = $0 }
            ))
            
            ToggleRow(icon: "icloud", title: "云端自动同步", isOn: Binding(
                get: { prefs.enableCloudSync },
                set: { prefs.enableCloudSync = $0 }
            ))
            
            ToggleRow(icon: "iphone.radiowaves.left.and.right", title: "触觉反馈", isOn: Binding(
                get: { prefs.hapticFeedbackEnabled },
                set: { prefs.hapticFeedbackEnabled = $0 }
            ))
        }
    }
    
    // MARK: Teen Mode Section
    
    private var teenModeSection: some View {
        section(header: "青少年保护") {
            ToggleRow(icon: "lock.shield.fill", title: "青少年模式", isOn: Binding(
                get: { prefs.enableTeenMode },
                set: { newValue in
                    prefs.enableTeenMode = newValue
                    if newValue {
                        activeSheet = .teenMode
                    }
                }
            ))
            
            if prefs.enableTeenMode {
                settingsRow(icon: "clock.fill", title: "每日使用时长", subtitle: "\(prefs.teenModeDailyLimitMinutes) 分钟") {
                    activeSheet = .teenMode
                }
            }
        }
    }
    
    // MARK: Data Section
    
    private var dataSection: some View {
        section(header: "数据管理") {
            settingsRow(icon: "square.and.arrow.down", title: "导出我的数据", subtitle: "获取你的所有故事和角色") {
                exportUserData()
            }
            
            settingsRow(icon: "trash.fill", title: "清除缓存", subtitle: "释放存储空间") {
                clearCache()
            }
            
            if authManager.currentUser != nil {
                settingsRow(icon: "person.badge.minus.fill", title: "删除账号", subtitle: "永久删除所有数据", tintColor: ColorPalette.error) {
                    showDeleteAccountConfirm = true
                }
            }
        }
    }
    
    // MARK: Privacy Section
    
    private var privacySection: some View {
        section(header: "隐私与合规") {
            settingsRow(icon: "doc.text", title: "问题反馈", subtitle: "遇到问题或有建议？告诉我们") {
                activeSheet = .reportForm
            }
            
            LinkRow(icon: "lock.fill", title: "隐私政策", url: URL(string: AppConfig.Store.privacyPolicyURL))
            
            LinkRow(icon: "doc.fill", title: "服务条款", url: URL(string: AppConfig.Store.termsOfServiceURL))
        }
    }
    
    // MARK: About Section
    
    private var aboutSection: some View {
        section(header: "关于") {
            HStack {
                Label("版本", systemImage: "info.circle")
                    .foregroundStyle(ColorPalette.textPrimary)
                
                Spacer()
                
                Text("1.0.0 (1)")
                    .foregroundStyle(ColorPalette.textSecondary)
            }
            
            LinkRow(icon: "envelope.fill", title: "联系我们", url: URL(string: "mailto:\(AppConfig.Store.contactEmail)"))
            
            HStack {
                Spacer()
                Text(AppConfig.Store.copyrightNotice)
                    .font(Typography.footnote(11))
                    .foregroundStyle(ColorPalette.textSecondary)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: Helpers

    /// 主题模式选择（跟随系统 / 浅色 / 深色）
    private var themeMenuRow: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    HapticManager.selection()
                    prefs.appTheme = theme
                } label: {
                    if prefs.appTheme == theme {
                        Label(theme.displayName, systemImage: "checkmark")
                    } else {
                        Text(theme.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "textformat")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorPalette.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("主题模式")
                        .font(Typography.body(15))
                        .foregroundStyle(ColorPalette.textPrimary)
                    Text(prefs.appTheme.displayName)
                        .font(Typography.footnote(12))
                        .foregroundStyle(ColorPalette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorPalette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func section<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header)
                .font(Typography.footnote(12))
                .foregroundStyle(ColorPalette.textSecondary)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorPalette.lightCardBackground)
            )
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func settingsRow(icon: String, title: String, subtitle: String? = nil, tintColor: Color = ColorPalette.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(tintColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.body(15))
                        .foregroundStyle(tintColor)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Typography.footnote(12))
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorPalette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func ToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorPalette.primary)
                .frame(width: 28)
            
            Text(title)
                .font(Typography.body(15))
                .foregroundStyle(ColorPalette.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ColorPalette.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    @ViewBuilder
    private func LinkRow(icon: String, title: String, url: URL?) -> some View {
        if let url = url {
            Link(destination: url) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(ColorPalette.textPrimary)
                        .frame(width: 28)
                    
                    Text(title)
                        .font(Typography.body(15))
                        .foregroundStyle(ColorPalette.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        } else {
            settingsRow(icon: icon, title: title) {}
        }
    }
    
    // MARK: Actions
    
    private func exportUserData() {
        Task { @MainActor in
            do {
                let stories = try DataManager.shared.fetchAllStories()
                var exportText = "# StoryWeave 数据导出\n\n"
                
                for story in stories {
                    let text = try DataManager.shared.exportStoryAsText(story)
                    exportText += text + "\n\n---\n\n"
                }
                
                // 分享导出
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("storyweave_export_\(Date().timeIntervalSince1970).txt")
                try exportText.write(to: tempURL, atomically: true, encoding: .utf8)
                
                // 触发分享菜单
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                // 显示错误
            }
        }
    }
    
    private func clearCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let imageDir = cacheDir.appendingPathComponent("StoryWeaveImages")
        try? FileManager.default.removeItem(at: imageDir)
        HapticManager.success()
    }

}

// MARK: - Teen Mode Settings

struct TeenModeSettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var prefs = UserPreferences.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("每日使用限制") {
                    Stepper(value: $prefs.teenModeDailyLimitMinutes, in: 15...240, step: 15) {
                        HStack {
                            Text("每日时长限制")
                            Spacer()
                            Text("\(prefs.teenModeDailyLimitMinutes) 分钟")
                                .foregroundStyle(ColorPalette.primary)
                        }
                    }
                }
                
                Section("内容限制") {
                    HStack {
                        Label("屏蔽惊悚恐怖题材", systemImage: "checkmark")
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                    HStack {
                        Label("启用严格内容审核", systemImage: "checkmark")
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                    HStack {
                        Label("禁止高级世界观访问", systemImage: "checkmark")
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                
                Section("关于青少年模式") {
                    Text("青少年模式旨在保护未成年人的身心健康。启用后将限制每日使用时长、屏蔽不适宜内容，并阻止访问付费功能。")
                        .font(Typography.footnote(12))
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            }
            .navigationTitle("青少年模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct FeedbackFormView: View {
    let source: String
    @Environment(\.dismiss) private var dismiss
    @State private var reasonIndex = 0
    @State private var note = ""

    private let reasons = ["不当内容", "抄袭/重复", "广告/垃圾", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("反馈原因")) {
                    Picker("选择原因", selection: $reasonIndex) {
                        ForEach(0..<reasons.count, id: \.self) { Text(reasons[$0]).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section(header: Text("备注（可选）")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .scrollContentBackground(.hidden)
                }
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("我们将在 24 小时内处理你的举报，并根据需要采取必要措施。")
                            .font(.footnote).foregroundStyle(ColorPalette.textSecondary)
                    }
                    Button {
                        let subject = "StoryWeave 举报 | \(source) | \(reasons[reasonIndex])"
                        let body = "备注：\(note)\n来源：\(source)"
                        let s = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let b = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "mailto:\(AppConfig.Store.contactEmail)?subject=\(s)&body=\(b)") {
                            UIApplication.shared.open(url)
                        }
                    } label: { Label("通过邮件反馈", systemImage: "envelope.fill") }
                }
            }
            .navigationTitle("反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

