import Foundation

// MARK: - App Configuration
/// 集中管理应用配置、API密钥占位符和功能开关

enum AppConfig {
    
    // MARK: - API Keys (生产环境请从 Secrets.plist 读取)
    enum API {
        /// Google Gemini API 密钥 - 从 Secrets.plist 读取
        static var geminiKey: String {
            Secrets.value(for: "GEMINI_API_KEY") ?? "YOUR_GEMINI_API_KEY_HERE"
        }
        
        /// OpenAI DALL-E API 密钥 - 从 Secrets.plist 读取
        static var dalleKey: String {
            Secrets.value(for: "OPENAI_API_KEY") ?? "YOUR_OPENAI_API_KEY_HERE"
        }
        
        /// 火山方舟 Seedream 文生图密钥
        static var seedreamKey: String {
            Secrets.value(for: "SEEDREAM_API_KEY")
                ?? Secrets.value(for: "ARK_API_KEY")
                ?? ""
        }

        /// Supabase 配置
        static var supabaseURL: String {
            Secrets.value(for: "SUPABASE_URL") ?? "YOUR_SUPABASE_URL_HERE"
        }
        
        static var supabaseAnonKey: String {
            Secrets.value(for: "SUPABASE_ANON_KEY") ?? "YOUR_SUPABASE_ANON_KEY_HERE"
        }
    }
    
    // MARK: - Subscription Limits
    enum Limits {
        /// 免费版每日故事创建次数
        static let freeDailyCreations = 5
        /// 免费版每日插图次数（免费层无插图，但保留结构）
        static let freeDailyImages = 0
        /// 付费版每月 AI 插图额度
        static let premiumMonthlyImages = 20
        /// 每段剧情的选择数量
        static let choiceCount = 4
        /// AI生成超时时间（秒）
        static let aiTimeout: TimeInterval = 30          // 底层 URLSession 硬超时
    static let aiFallback: TimeInterval = 12          // 12 秒兜底触发重 roll
    }
    
    // MARK: - Feature Flags
    enum Features {
        /// 是否启用AI插图生成
        static let enableSceneImages = true
        /// 是否启用青少年模式
        static let enableTeenMode = true
        /// 是否启用云端同步
        static let enableCloudSync = true
        /// 是否启用内容审核
        static let enableContentModeration = true
    }
    
    // MARK: - App Store Info
    enum Store {
        static let appID = "0000000000"  // TODO: 替换为真实App Store ID
        static let appStoreURL = "https://apps.apple.com/app/id\(appID)"
        static let contactEmail = "support@storyweave.ai"
        static let privacyPolicyURL = "https://storyweave.ai/privacy"
        static let termsOfServiceURL = "https://storyweave.ai/terms"
        static let copyrightNotice = "© 2026 StoryWeave. All rights reserved."
    }
}

// MARK: - Secrets Loader
/// 从 Secrets.plist 加载敏感配置（不纳入版本控制）

enum Secrets {
    static func value(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let value = plist[key] as? String else {
            return nil
        }
        return value.isEmpty ? nil : value
    }
}

// MARK: - Subscription Product IDs
/// StoreKit 2 产品标识符

enum ProductIDs {
    // 订阅（三档）
    static let weekly  = "com.storyweave.premium.weekly"
    static let monthly = "com.storyweave.premium.monthly"
    static let yearly  = "com.storyweave.premium.yearly"

    // Story Credits（插图积分）
    static let creditsPack10   = "com.storyweave.credits.10"
    static let creditsPack50   = "com.storyweave.credits.50"
    static let creditsPack120  = "com.storyweave.credits.120"
    static let creditsPack240  = "com.storyweave.credits.240"

    // 消耗型内购（保留向后兼容）
    static let plotTwistCard = "com.storyweave.items.plottwist"

    static let allSubscriptionIDs: Set<String> = [weekly, monthly, yearly]
    static let allCreditsIDs: Set<String> = [creditsPack10, creditsPack50, creditsPack120, creditsPack240]
    static let allConsumableIDs: Set<String> = allCreditsIDs.union([plotTwistCard])
    static let allProductIDs: Set<String> = allSubscriptionIDs.union(allConsumableIDs)
}


    // MARK: - Subscription Pricing (USD)
    enum Pricing {
        static let weeklyPrice: Double = 4.99
        static let monthlyPrice: Double = 9.99
        static let yearlyPrice: Double = 59.99
        static let trialDays = 7
    }

    // MARK: - URLs (合规用, 可配置)
    enum Legal {
        static let privacyPolicy = "https://storyweave.ai/privacy"
        static let termsOfService = "https://storyweave.ai/terms"
        static let eula = "https://storyweave.ai/eula"
        static let contactEmail = "support@storyweave.ai"
    }
