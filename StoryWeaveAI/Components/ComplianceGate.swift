import SwiftUI

// MARK: - Compliance Gate
/// 首屏合规门控：AI 数据共享同意 + 年龄门控 + EULA
/// 必须在首次启动时依次通过，不可跳过

enum ComplianceGateState {
    case notChecked
    case aiConsentRequired
    case ageGateRequired
    case eulaRequired
    case passed
}

@MainActor
final class ComplianceManager: ObservableObject {

    static let shared = ComplianceManager()

    @Published var state: ComplianceGateState = .notChecked

    private enum Keys {
        static let aiConsent = "compliance.ai_consent"
        static let aiConsentDate = "compliance.ai_consent_date"
        static let ageConfirmed = "compliance.age_confirmed"
        static let eulaAccepted = "compliance.eula_accepted"
        static let eulaVersion = "compliance.eula_version"
        static let currentEulaVersion = "1.0"
    }

    // MARK: Init

    private init() {
        loadState()
    }

    private func loadState() {
        let prefs = UserDefaults.standard
        let aiConsent = prefs.bool(forKey: Keys.aiConsent)
        let age = prefs.bool(forKey: Keys.ageConfirmed)
        let eula = prefs.string(forKey: Keys.eulaVersion) == Keys.currentEulaVersion

        if aiConsent && age && eula {
            state = .passed
        } else if !age {
            state = .ageGateRequired
        } else if !aiConsent {
            state = .aiConsentRequired
        } else {
            state = .eulaRequired
        }
    }

    // MARK: Actions

    func confirmAge(_ isTeen: Bool) {
        UserDefaults.standard.set(true, forKey: Keys.ageConfirmed)
        UserDefaults.standard.set(isTeen, forKey: "teen_mode_promoted")
        loadState()
    }

    func grantAIConsent() {
        UserDefaults.standard.set(true, forKey: Keys.aiConsent)
        UserDefaults.standard.set(Date(), forKey: Keys.aiConsentDate)
        loadState()
    }

    func denyAIConsent() {
        // 严格模式：必须同意才能用（P0 合规要求）
        // 可以降级为只读浏览模式，但本期按合规要求：必须同意才能用 AI 功能
        // 这里我们设为同意但标记为 "denied" 以便 UI 弹出说明
        UserDefaults.standard.set(false, forKey: Keys.aiConsent)
    }

    func acceptEULA() {
        UserDefaults.standard.set(Keys.currentEulaVersion, forKey: Keys.eulaVersion)
        loadState()
    }

    var isCompliant: Bool { state == .passed }
}

// MARK: - EULA 同意弹窗

struct EULASheet: View {
    @ObservedObject private var compliance = ComplianceManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(ColorPalette.primary.opacity(0.12)).frame(width: 80, height: 80)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 36)).foregroundStyle(ColorPalette.primary)
                }
                .padding(.top, 40)

                Text("最终用户许可协议")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("请阅读并同意 StoryWeave 的服务条款和隐私政策后使用。")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(spacing: 10) {
                    Link(destination: URL(string: AppConfig.Store.privacyPolicyURL)!) {
                        Label("阅读隐私政策", systemImage: "hand.raised.shield.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(ColorPalette.primary.opacity(0.08)))
                    }

                    Link(destination: URL(string: AppConfig.Store.termsOfServiceURL)!) {
                        Label("阅读服务条款", systemImage: "doc.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(ColorPalette.primary.opacity(0.08)))
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                PrimaryButton("同意并开始使用", icon: "checkmark.shield.fill") {
                    compliance.acceptEULA()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)

                Button {
                    // 不同意 → 降级：让用户退出（系统最小化）
                    UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                } label: {
                    Text("不同意")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                .padding(.bottom, 10)
            }
            .background(ColorPalette.bg)
            .navigationTitle("许可协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - AI 数据共享同意弹窗

struct AIDataConsentSheet: View {
    @ObservedObject private var compliance = ComplianceManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showProviders = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 头部 icon
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(ColorPalette.primary.opacity(0.12)).frame(width: 64, height: 64)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(ColorPalette.primary)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)

                    Text("AI 服务数据共享同意")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("StoryWeave 使用第三方 AI 服务为你生成故事内容。我们需要将你的故事设定、角色信息和写作请求发送给以下 AI 提供商。")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(ColorPalette.textSecondary)

                    // Provider 列表
                    VStack(alignment: .leading, spacing: 10) {
                        providerRow(name: "DeepSeek", country: "中国", detail: "文本生成")
                        providerRow(name: "Seedream (火山方舟)", country: "中国", detail: "图像生成")
                        providerRow(name: "Google Gemini (可选)", country: "美国", detail: "文本生成")
                        providerRow(name: "OpenAI DALL-E (可选)", country: "美国", detail: "图像生成")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorPalette.primary.opacity(0.04)))

                    Text("你可以随时在「设置 → 隐私」中撤回同意或切换服务提供商。撤回后 AI 功能将暂停，直到你重新同意。")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(ColorPalette.textTertiary)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(ColorPalette.bg)
            .navigationTitle("数据共享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    VStack(spacing: 8) {
                        PrimaryButton("同意并继续", icon: "checkmark.shield.fill") {
                            compliance.grantAIConsent()
                        }
                        Button("暂不同意", role: .destructive) {
                            compliance.denyAIConsent()
                            dismiss()
                        }
                        .foregroundStyle(ColorPalette.textTertiary)
                        .font(.system(size: 13))
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func providerRow(name: String, country: String, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(ColorPalette.textTertiary)
            }
            Spacer()
            Text(country)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(ColorPalette.textTertiary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(ColorPalette.divider))
        }
    }
}


// MARK: - 首次启动欢迎 + 合规（一页三模块，一次提交）

struct WelcomeConsentView: View {
    @ObservedObject private var compliance = ComplianceManager.shared

    @State private var ageConfirmed: Bool? = nil        // nil=未选, true=<13, false=≥13
    @State private var aiConsent: Bool = false
    @State private var eulaAccepted: Bool = false
    @State private var showProvidersDetail = false

    var canContinue: Bool {
        ageConfirmed != nil && aiConsent && eulaAccepted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    ageBlock
                    aiBlock
                    eulaBlock
                    Spacer(minLength: 30)
                    primaryAction
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .background(ColorPalette.bg.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(ColorPalette.brandGradient.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(ColorPalette.primary)
            }
            Text("欢迎来到 StoryWeave")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("在你开始编织故事之前，我们需要你确认几项设置。只需 30 秒。")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: 年龄确认

    private var ageBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "person.text.rectangle.fill", title: "① 年龄确认", subtitle: "根据 App Store 审核要求")

            HStack(spacing: 10) {
                ageOption(isTeen: false, title: "我已满 13 岁", icon: "checkmark.circle.fill",
                          selected: ageConfirmed == false, accent: ColorPalette.primary)
                ageOption(isTeen: true, title: "未满 13 岁", icon: "shield.fill",
                          selected: ageConfirmed == true, accent: ColorPalette.accent)
            }
        }
    }

    private func ageOption(isTeen: Bool, title: String, icon: String, selected: Bool, accent: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { ageConfirmed = isTeen }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundStyle(selected ? .white : ColorPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(selected ? accent : ColorPalette.primary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? accent.opacity(0) : ColorPalette.primary.opacity(0.15), lineWidth: 1))
            .scaleEffect(selected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
    }

    // MARK: AI 数据共享

    private var aiBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "sparkles", title: "② AI 数据共享同意", subtitle: "我们会将你的故事设定发送给以下 AI 提供商生成内容")

            if showProvidersDetail {
                VStack(alignment: .leading, spacing: 6) {
                    providerRow(name: "DeepSeek", detail: "文本生成（中国）", icon: "text.bubble.fill")
                    providerRow(name: "Seedream（火山方舟）", detail: "图像生成（中国）", icon: "photo.on.rectangle")
                    providerRow(name: "Google Gemini（可选）", detail: "文本生成（美国）", icon: "globe")
                    providerRow(name: "OpenAI DALL-E（可选）", detail: "图像生成（美国）", icon: "paintpalette.fill")
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(ColorPalette.primary.opacity(0.04)))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showProvidersDetail.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(showProvidersDetail ? "收起提供商详情" : "查看 AI 提供商详情")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorPalette.primary)
                    Image(systemName: showProvidersDetail ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
            }

            toggleRow(isOn: $aiConsent, title: "同意发送数据以生成 AI 内容",
                      subtitle: "你可以随时在设置中撤回同意")
        }
    }

    private func providerRow(name: String, detail: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(ColorPalette.primary)
            Text(name).font(.system(size: 13, weight: .medium))
            Spacer()
            Text(detail).font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
        }
    }

    // MARK: EULA

    private var eulaBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "doc.text.fill", title: "③ 许可协议", subtitle: "请阅读并同意后使用")

            VStack(alignment: .leading, spacing: 6) {
                Link(destination: URL(string: AppConfig.Store.privacyPolicyURL)!) {
                    HStack {
                        Image(systemName: "hand.raised.shield.fill").font(.system(size: 14))
                        Text("阅读隐私政策").font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right.square").font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
                    }
                }
                Link(destination: URL(string: AppConfig.Store.termsOfServiceURL)!) {
                    HStack {
                        Image(systemName: "doc.fill").font(.system(size: 14))
                        Text("阅读服务条款").font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right.square").font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(ColorPalette.primary.opacity(0.04)))

            toggleRow(isOn: $eulaAccepted, title: "我已阅读并同意以上条款", subtitle: "")
        }
    }

    // MARK: 底部主按钮

    private var primaryAction: some View {
        VStack(spacing: 10) {
            Button {
                guard let age = ageConfirmed else { return }
                compliance.confirmAge(age)
                compliance.grantAIConsent()
                compliance.acceptEULA()
            } label: {
                HStack {
                    Spacer()
                    Label("开始编织故事", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.white)
                .frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(canContinue ? ColorPalette.brandGradient : LinearGradient(colors: [ColorPalette.textTertiary], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .scaleEffect(canContinue ? 1.0 : 0.98)
                .animation(.easeInOut(duration: 0.15), value: canContinue)
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)

            Text("未满 13 岁将自动启用青少年模式")
                .font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
        }
    }

    // MARK: 公共组件

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(ColorPalette.primary.opacity(0.12)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(ColorPalette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
            }
        }
    }

    private func toggleRow(isOn: Binding<Bool>, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isOn.wrappedValue.toggle() }
            } label: {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isOn.wrappedValue ? ColorPalette.primary : ColorPalette.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .medium, design: .rounded))
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(ColorPalette.textTertiary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - AI 生成标注角标

struct AIGeneratedBadge: View {
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: compact ? 9 : 11))
            Text(compact ? "AI" : "AI-generated")
                .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }
}
