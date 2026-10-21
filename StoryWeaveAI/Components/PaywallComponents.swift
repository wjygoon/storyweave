import SwiftUI

// MARK: - Paywall Popup
/// 全局统一付费弹窗：毛玻璃 + 可下滑关闭 + 渐进式转化逻辑
/// 支持青少年模式屏蔽

struct PaywallPopup: View {
    @Binding var isPresented: Bool
    let context: PaywallContext

    @StateObject private var storeKit: StoreKitManager = StoreKitManager.shared
    @StateObject private var quota = QuotaManager.shared
    @State private var showSubscription = false
    @State private var isTeenMode: Bool = UserPreferences.shared.enableTeenMode

    // 是否允许关闭（第三次及以后）
    private var allowGracefulDismiss: Bool { quota.paywallDismissCount >= 2 }
    // 渐进式：第一次关闭赠送额度
    private var isFirstDismiss: Bool { quota.paywallDismissCount == 0 }

    var body: some View {
        // 青少年模式：完全屏蔽付费弹窗
        if isTeenMode {
            EmptyView()
        } else {
            ZStack {
                // 背景 dim
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { if allowGracefulDismiss { handleDismiss() } }

                // 弹窗卡片
                VStack(spacing: Spacing.md) {
                    // 拖拽把手
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorPalette.textTertiary.opacity(0.5))
                        .frame(width: 36, height: 4)
                        .padding(.top, Spacing.sm)

                    // Crown icon
                    ZStack {
                        Circle().fill(ColorPalette.gold.opacity(0.15)).frame(width: 56, height: 56)
                        Image(systemName: "crown.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(ColorPalette.gold)
                    }

                    Text(context.headline)
                        .font(Typography.title(17))
                        .foregroundStyle(ColorPalette.textStrong)

                    Text(context.subheadline)
                        .font(Typography.body(13))
                        .foregroundStyle(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)

                    // 权益摘要
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        benefitRow("无限剧情生成", icon: "infinity")
                        benefitRow("无限高清插图", icon: "photo.on.rectangle")
                        benefitRow("全部世界观 + 每月限定", icon: "globe.desk")
                        benefitRow("云端自动同步", icon: "icloud.and.arrow.up")
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)

                    // CTA
                    PrimaryButton(
                        "立即开通 Premium",
                        icon: "crown.fill",
                        tint: .gold,
                        action: {
                            HapticManager.success()
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showSubscription = true
                            }
                        }
                    )
                    .padding(.horizontal, Spacing.md)

                    // 次按钮
                    Button {
                        handleDismiss()
                    } label: {
                        Text(allowGracefulDismiss ? "再想想" : (isFirstDismiss ? "先送我 1 次额度" : "再看看年付优惠"))
                            .font(Typography.footnote(13))
                            .foregroundStyle(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.bottom, Spacing.md)
                .frame(maxWidth: 400)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.white.opacity(0.15)))
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(ColorPalette.gold)
            Text(text).font(Typography.body(12)).foregroundStyle(ColorPalette.textPrimary)
        }
    }

    private func handleDismiss() {
        quota.paywallDismissCount += 1

        if isFirstDismiss {
            // 第一次关闭：送 1 次
            quota.grantTemporaryStory(1)
        } else if quota.paywallDismissCount == 1 {
            // 第二次：展示限时优惠 — 这里在 SubView 里弹
        }
        // 第三次及以上：直接关闭

        HapticManager.selection()
        isPresented = false
    }
}

// MARK: - Quota Ring View (Top Nav Right)

struct QuotaRingView: View {
    @StateObject private var quota = QuotaManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack(spacing: 6) {
                if storeKit.isPremium || quota.isPremiumOrTrialActive {
                    // Premium badge
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill").font(.system(size: 10, weight: .bold))
                        Text("PRO").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(ColorPalette.goldGradient))
                } else {
                    // Quota ring
                    ZStack {
                        Circle()
                            .stroke(ColorPalette.hairline, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: max(0, quota.storyQuotaProgress))
                            .stroke(quota.quotaColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: quota.storyQuotaProgress)
                        Text("\(quota.remainingStoryGenerations)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorPalette.textStrong)
                    }
                    .frame(width: 28, height: 28)
                }
            }
        }
    }
}

// MARK: - Top Quota Strip (Reading Page)

struct TopQuotaStrip: View {
    @StateObject private var quota = QuotaManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    let onPaywall: () -> Void

    var body: some View {
        if !storeKit.isPremium && !quota.isPremiumOrTrialActive {
            HStack {
                Image(systemName: "sparkles").font(.system(size: 11))
                Text("每日剩余 \(quota.remainingStoryGenerations) 次生成")
                    .font(Typography.footnote(11))
                Spacer()
                Button("升级", action: onPaywall)
                    .font(Typography.micro(11))
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorPalette.gold)
            }
            .foregroundStyle(quota.remainingStoryGenerations <= 1 ? ColorPalette.error : ColorPalette.textSecondary)
            .padding(.horizontal, Spacing.page).padding(.vertical, 6)
            .background(ColorPalette.divider)
            .overlay(alignment: .bottom) {
                if quota.remainingStoryGenerations <= 1 {
                    ColorPalette.error.frame(height: 1)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - CheckIn Card

struct CheckInCard: View {
    @StateObject private var quota = QuotaManager.shared
    @State private var showToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle().fill(ColorPalette.gold.opacity(0.15)).frame(width: 36, height: 36)
                        Image(systemName: "gift.fill").font(.system(size: 16)).foregroundStyle(ColorPalette.gold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quota.hasCheckedInToday ? "今日已签到" : "每日签到")
                            .font(Typography.caption(14))
                            .fontWeight(.semibold)
                        Text(quota.hasCheckedInToday ? "明天再来领额度吧" : "+1 次剧情额度")
                            .font(Typography.footnote(11))
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                Spacer()

                Button {
                    HapticManager.success()
                    let ok = quota.performCheckIn()
                    if ok {
                        showToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showToast = false }
                    }
                } label: {
                    Text(quota.hasCheckedInToday ? "已领" : "签到")
                        .font(Typography.footnote(12))
                        .fontWeight(.semibold)
                        .foregroundStyle(quota.hasCheckedInToday ? ColorPalette.textTertiary : .white)
                        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
                        .background(
                            Capsule().fill(quota.hasCheckedInToday ? AnyShapeStyle(ColorPalette.divider) : AnyShapeStyle(ColorPalette.goldGradient))
                        )
                }
                .buttonStyle(.plain)
                .disabled(quota.hasCheckedInToday)
            }
        }
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(ColorPalette.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(ColorPalette.hairline))
        .overlay(alignment: .topTrailing) {
            if showToast {
                Text("签到成功 +1 ✨")
                    .font(Typography.footnote(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
                    .background(Capsule().fill(ColorPalette.success))
                    .padding(.top, -Spacing.xs)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showToast)
    }
}

// MARK: - Premium Gate Overlay for World Templates

struct PremiumGateOverlay: View {
    let label: String = "VIP"
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 18)).foregroundStyle(ColorPalette.gold)
                Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(ColorPalette.gold))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

// MARK: - Trial Reminder Banner

struct TrialReminderBanner: View {
    @StateObject private var quota = QuotaManager.shared
    let action: () -> Void

    var body: some View {
        if let remaining = quota.trialDaysRemaining, remaining <= 1 {
            HStack {
                Image(systemName: "bell.badge.fill").foregroundStyle(ColorPalette.error)
                Text(remaining == 0 ? "会员试用即将到期！" : "试用期还剩 \(remaining) 天")
                    .font(Typography.body(13))
                Spacer()
                Button("续费", action: action)
                    .font(Typography.footnote(12))
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorPalette.gold)
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(ColorPalette.gold.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(ColorPalette.gold.opacity(0.3)))
            )
        }
    }
}
