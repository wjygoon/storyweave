import SwiftUI
import StoreKit

// MARK: - Subscription View
/// 付费转化核心页：免费 vs Premium 对比 + 年付高亮 + 7天试用引导 + 合规

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @StateObject private var quota = QuotaManager.shared

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    enum SubscriptionPlan: String, CaseIterable, Identifiable {
        case yearly, monthly, weekly
        var id: String { rawValue }
        var displayName: String { switch self { case .yearly: return "年付"; case .monthly: return "月付"; case .weekly: return "周付" } }
        var productID: String {
            switch self {
            case .yearly: return ProductIDs.yearly
            case .monthly: return ProductIDs.monthly
            case .weekly: return ProductIDs.weekly
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    heroSection
                    featureComparison
                    planSelection
                    CTAAndLegal
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100) // safety area + button breathing room
            }
            .background(ColorPalette.bg.ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("恢复购买") { Task { try? await storeKit.restorePurchases() } }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorPalette.primary)
                }
            }
            .alert("购买失败", isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("好的", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(ColorPalette.gold.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ColorPalette.gold)
            }
            .padding(.top, 8)

            Text("解锁全部创作自由")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ColorPalette.textStrong)

            Text("7 天免费试用 · 随时取消")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(ColorPalette.textSecondary)

            // Trust badges — 2 only, light green bg, rounded 8pt, padding 8pt
            HStack(spacing: 8) {
                trustBadge("随时取消")
                trustBadge("7 天免费试用")
            }
            .padding(.top, 4)
        }
    }

    private func trustBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(ColorPalette.success)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ColorPalette.success.opacity(0.12))
            )
    }

    // MARK: Feature Comparison Table

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("权益对比")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ColorPalette.textStrong)

            VStack(spacing: 0) {
                // Header row — 功能 / 免费版 / Premium — bold + alignments
                HStack(spacing: 0) {
                    Text("功能")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("免费版")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorPalette.textSecondary)
                        .frame(width: 80, alignment: .center)
                    Text("Premium")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorPalette.gold)
                        .frame(width: 100, alignment: .center)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(ColorPalette.bg)

                featureRow("每日剧情额度", free: "3 次", premium: "无限", premiumCheck: false)
                featureRow("每日插图额度", free: "1 次", premium: "无限", premiumCheck: false)
                featureRow("世界观模板", free: "14 套", premium: "全部 + 每月限定", premiumCheck: false)
                featureRow("高清场景插图", free: "—", premium: "✓")
                featureRow("隐藏剧情结局", free: "—", premium: "✓")
                featureRow("时间线回溯", free: "5 次/天", premium: "无限", premiumCheck: false)
                featureRow("云端自动同步", free: "—", premium: "✓")
                featureRow("AI 优先通道", free: "—", premium: "✓")
                featureRow("高清分享卡", free: "基础", premium: "金色尊享", premiumCheck: false)
                featureRow("订阅专属道具", free: "高价限购", premium: "低价 + 无限", premiumCheck: false)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ColorPalette.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func featureRow(_ name: String, free: String, premium: String, premiumCheck: Bool = true) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(ColorPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(ColorPalette.textTertiary)
                .frame(width: 80, alignment: .center)
            HStack(spacing: 4) {
                if premiumCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(premium)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(ColorPalette.gold)
            .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorPalette.hairline)
                .frame(height: 0.5)
        }
    }

    // MARK: Plan Selection

    private var planSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择套餐")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ColorPalette.textStrong)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    planCard(.yearly)
                    planCard(.monthly)
                }
                planCard(.weekly)
            }
        }
        .padding(.top, 0)
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let isSelected = selectedPlan == plan
        let isYearly = plan == .yearly

        return Button {
            HapticManager.selection()
            selectedPlan = plan
        } label: {
            VStack(spacing: 6) {
                if isYearly {
                    Text("最推荐 · 日均 $0.16")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(ColorPalette.gold)
                        )
                } else {
                    Spacer().frame(height: 19) // match yearly badge height
                }

                Text(plan.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isYearly ? ColorPalette.gold : ColorPalette.textPrimary)

                Text(isYearly ? "$59.99" : (plan == .monthly ? "$9.99" : "$4.99"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isYearly ? ColorPalette.gold : ColorPalette.textStrong)

                Text(isYearly ? "/ 年" : (plan == .monthly ? "/ 月" : "/ 周"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(ColorPalette.textSecondary)

                if plan == .yearly {
                    Text("含 7 天免费试用")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorPalette.success)
                }
            }
            .frame(maxWidth: .infinity, minHeight: nil)
            .frame(height: 140)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isYearly
                          ? (isSelected ? ColorPalette.gold.opacity(0.12) : ColorPalette.gold.opacity(0.05))
                          : ColorPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                            ? (isYearly ? ColorPalette.gold : ColorPalette.primary)
                            : ColorPalette.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: CTA + Legal

    private var CTAAndLegal: some View {
        VStack(spacing: 14) {
            // Main purchase button — full width, 56pt tall, gold gradient
            Button(action: performPurchase) {
                HStack(spacing: 6) {
                    Text(ctaButtonText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: nil)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ColorPalette.goldGradient)
                )
                .shadow(color: ColorPalette.gold.opacity(0.4), radius: 16, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            // Legal — compact & clear
            VStack(spacing: 6) {
                Text(selectedPlan == .yearly
                     ? "试用期结束后自动扣费 $59.99/年。可随时取消。"
                     : "$7.99/月，可随时取消。")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(ColorPalette.textTertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link("订阅条款", destination: URL(string: "https://storyweave.ai/terms")!)
                    Link("隐私政策", destination: URL(string: "https://storyweave.ai/privacy")!)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ColorPalette.primary)
            }
        }
        .padding(.top, 8)
    }

    private var ctaButtonText: String {
        switch selectedPlan {
        case .yearly: return "开启 7 天免费试用"
        case .monthly: return "立即开通月付"
        case .weekly: return "立即开通周付"
        }
    }

    private func performPurchase() {
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                let products = try await Product.products(for: [selectedPlan.productID])
                guard let product = products.first else {
                    purchaseError = "无法获取产品信息，请稍后再试"
                    return
                }
                let success = try await storeKit.purchase(product)
                if success {
                    if selectedPlan == .yearly {
                        QuotaManager.shared.setTrialStart(7)
                    }
                    HapticManager.success()
                    dismiss()
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }
}
