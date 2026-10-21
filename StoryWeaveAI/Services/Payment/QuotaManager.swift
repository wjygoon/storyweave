import Foundation
import SwiftUI

// MARK: - Quota Manager

@MainActor
final class QuotaManager: ObservableObject {

    static let shared = QuotaManager()

    @Published var remainingStoryGenerations: Int
    @Published var remainingImageGenerations: Int
    @Published var totalRewardedGenerations: Int
    @Published var lastDailyReset: Date
    @Published var hasCheckedInToday: Bool
    @Published var lastCheckInDate: Date?
    @Published var paywallDismissCount: Int
    @Published var isShowingPaywall: Bool = false
    @Published var paywallContext: PaywallContext = .quotaExhausted
    @Published var trialEndDate: Date?

    static let FREE_DAILY_STORY = 5
    static let FREE_DAILY_IMAGE = 0
    static let SIGN_IN_REWARD = 1
    static let ONBOARD_BONUS = 5

    private init() {
        let d = UserDefaults.standard
        remainingStoryGenerations = d.object(forKey: "q_remaining_story") as? Int ?? Self.ONBOARD_BONUS
        remainingImageGenerations = d.object(forKey: "q_remaining_image") as? Int ?? Self.FREE_DAILY_IMAGE
        totalRewardedGenerations = d.object(forKey: "q_rewarded") as? Int ?? 0
        lastDailyReset = d.object(forKey: "q_last_reset") as? Date ?? Date()
        hasCheckedInToday = d.bool(forKey: "q_checked_in_today")
        lastCheckInDate = d.object(forKey: "q_last_checkin") as? Date
        paywallDismissCount = d.object(forKey: "q_paywall_dismiss") as? Int ?? 0
        trialEndDate = d.object(forKey: "q_trial_end") as? Date

        if d.object(forKey: "q_onboard_claimed") == nil {
            remainingStoryGenerations = Self.ONBOARD_BONUS
            remainingImageGenerations = Self.FREE_DAILY_IMAGE
            d.set(true, forKey: "q_onboard_claimed")
        }

        resetDailyIfNeeded()
    }

    // MARK: Daily Reset
    func resetDailyIfNeeded() {
        let cal = Calendar.current
        if !cal.isDateInToday(lastDailyReset) {
            lastDailyReset = Date()
            remainingStoryGenerations = Self.FREE_DAILY_STORY + totalRewardedGenerations
            remainingImageGenerations = Self.FREE_DAILY_IMAGE
            hasCheckedInToday = false
            sync()
        }
    }

    private func sync() {
        let d = UserDefaults.standard
        d.set(remainingStoryGenerations, forKey: "q_remaining_story")
        d.set(remainingImageGenerations, forKey: "q_remaining_image")
        d.set(totalRewardedGenerations, forKey: "q_rewarded")
        d.set(lastDailyReset, forKey: "q_last_reset")
        d.set(hasCheckedInToday, forKey: "q_checked_in_today")
        d.set(lastCheckInDate, forKey: "q_last_checkin")
        d.set(paywallDismissCount, forKey: "q_paywall_dismiss")
        d.set(trialEndDate, forKey: "q_trial_end")
    }

    // MARK: Check-In
    func performCheckIn() -> Bool {
        resetDailyIfNeeded()
        guard !hasCheckedInToday else { return false }
        hasCheckedInToday = true
        lastCheckInDate = Date()
        totalRewardedGenerations += Self.SIGN_IN_REWARD
        remainingStoryGenerations += Self.SIGN_IN_REWARD
        sync()
        HapticManager.success()
        return true
    }

    // MARK: Consume
    @discardableResult
    func consumeStoryGeneration() -> Bool {
        resetDailyIfNeeded()
        guard remainingStoryGenerations > 0 else { return false }
        remainingStoryGenerations -= 1
        sync()
        return true
    }

    @discardableResult
    func consumeImageGeneration() -> Bool {
        resetDailyIfNeeded()
        guard remainingImageGenerations > 0 else { return false }
        remainingImageGenerations -= 1
        sync()
        return true
    }

    // MARK: Grant
    func grantTemporaryStory(_ count: Int) {
        totalRewardedGenerations += count
        remainingStoryGenerations += count
        sync()
    }

    // MARK: Premium Override
    func setPremiumUnlimited(_ isPremium: Bool) { sync() }

    // MARK: Trial
    func setTrialStart(_ days: Int = 7) {
        trialEndDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        sync()
    }

    // MARK: Display Helpers
    var isPremiumOrTrialActive: Bool {
        if StoreKitManager.shared.isPremium { return true }
        if let end = trialEndDate { return Date() < end }
        return false
    }

    var trialDaysRemaining: Int? {
        guard let end = trialEndDate, Date() < end else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }

    var storyQuotaProgress: Double {
        guard !isPremiumOrTrialActive else { return 1.0 }
        let total = Double(Self.FREE_DAILY_STORY + totalRewardedGenerations)
        return total > 0 ? Double(remainingStoryGenerations) / total : 0
    }

    var quotaColor: Color {
        if isPremiumOrTrialActive { return ColorPalette.gold }
        if storyQuotaProgress > 0.5 { return ColorPalette.success }
        if storyQuotaProgress > 0.2 { return ColorPalette.gold }
        return ColorPalette.error
    }

    // MARK: Paywall Trigger Timing (P0)

    func recordStoryCompletion() {
        let count = UserDefaults.standard.integer(forKey: "paywall.stories_completed") + 1
        UserDefaults.standard.set(count, forKey: "paywall.stories_completed")
    }

    var shouldTriggerPaywallAfterStory: Bool {
        let count = UserDefaults.standard.integer(forKey: "paywall.stories_completed")
        return count >= 2 && !isPremiumOrTrialActive
    }

    var shouldTriggerPaywallOnRewind: Bool { !isPremiumOrTrialActive }

    func markRewindPromptShown() {
        UserDefaults.standard.set(true, forKey: "paywall.rewind_prompt_shown")
    }
}

// MARK: - Feature Gate

enum FeatureGate: String, CaseIterable {
    case unlimitedCreations, unlimitedImages, unlimitedRewinds
    case premiumWorldTemplates, monthlyLimitedWorld, cloudSync
    case HDSceneImages, sceneAnimations, premiumCharacters
    case priorityQueue, premiumShareCard, hiddenEndings
    case subscriptionDiscount, trialReminders
}

// MARK: - Entitlement Manager

@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    func has(_ feature: FeatureGate) -> Bool {
        if QuotaManager.shared.isPremiumOrTrialActive { return true }
        return false
    }

    var freeRewindLimit: Int { 5 }

    func isTeenModeBlockingPaywall() -> Bool {
        UserPreferences.shared.enableTeenMode
    }
}

// MARK: - Paywall Context

enum PaywallContext {
    case quotaExhausted
    case premiumFeature(FeatureGate)
    case worldTemplateLocked
    case hiddenEndingLocked
    case escapeSheet
    case shareSuccess
    case trialExpiring
    case generationLimit
    case climaxTriggered
    case rewindExhausted

    var headline: String {
        switch self {
        case .quotaExhausted: return "今日额度已用完"
        case .premiumFeature: return "解锁会员专属功能"
        case .worldTemplateLocked: return "这是 Premium 世界观"
        case .hiddenEndingLocked: return "解锁 VIP 隐藏结局"
        case .escapeSheet: return "云端备份防止故事丢失"
        case .shareSuccess: return "生成高清分享卡"
        case .trialExpiring: return "试用即将到期"
        case .generationLimit: return "额度不足"
        case .climaxTriggered: return "剧情高潮来了"
        case .rewindExhausted: return "回溯次数已用完"
        }
    }

    var subheadline: String {
        switch self {
        case .quotaExhausted: return "开通会员，无限生成剧情和插图"
        case .premiumFeature(let f): return "「\(featureName(f))」是会员专属功能"
        case .worldTemplateLocked: return "每月新增限定世界观"
        case .hiddenEndingLocked: return "每个故事都有专属隐藏结局"
        case .escapeSheet: return "会员自动备份全部故事到云端"
        case .shareSuccess: return "高清图 + 专属金色样式"
        case .trialExpiring: return "继续享受全部创作自由"
        case .generationLimit: return "升级后无限创作"
        case .climaxTriggered: return "解锁接下来的隐藏剧情"
        case .rewindExhausted: return "会员无限次回溯时间线"
        }
    }

    private func featureName(_ f: FeatureGate) -> String {
        switch f {
        case .HDSceneImages: return "高清插图"
        case .premiumCharacters: return "全属性自定义角色"
        case .cloudSync: return "云端自动同步"
        case .hiddenEndings: return "隐藏结局"
        case .priorityQueue: return "AI 优先通道"
        default: return "Premium 专属"
        }
    }
}
