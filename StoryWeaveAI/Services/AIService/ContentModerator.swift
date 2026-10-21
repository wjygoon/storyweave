import Foundation

// MARK: - Local Content Moderator
/// 本地敏感词过滤（双层审核的第一层）

final class ContentModerator {
    
    // MARK: - Sensitive Word Lists
    
    /// 色情相关词汇
    private static let sexualKeywords: [String] = [
        // 英文
        "porn", "xxx", "nude", "naked", "sex scene", "erotic",
        // 中文
        "色情", "露点", "裸体", "性行为", "床戏"
    ]
    
    /// 暴力相关词汇
    private static let violenceKeywords: [String] = [
        // 极端暴力
        "graphic violence", "brutally murdered", "tortured to death",
        // 中文
        "残忍杀害", "血腥屠杀", "碎尸万段"
    ]
    
    /// 自残/自杀相关词汇
    private static let selfHarmKeywords: [String] = [
        "suicide", "kill myself", "end my life", "self-harm",
        "自杀", "结束生命", "自残"
    ]
    
    /// 仇恨/歧视相关词汇
    private static let hateKeywords: [String] = [
        "racial slur", "hate speech", "genocide",
        "种族歧视", "种族灭绝", "仇恨言论"
    ]
    
    /// 违禁物品
    private static let illegalKeywords: [String] = [
        "hardcore drugs", "cocaine production", "meth lab",
        "制造毒品", "贩卖武器", "军火交易"
    ]
    
    // MARK: Public API
    
    /// 本地快速审核
    /// 输出二次审核（零成本本地 re-scan）。输入审核结果 + 安全指令
    static func validateOutput(_ text: String) -> ContentModerationResult {
        let result = moderateLocally(text)
        if !result.isSafe { return result }
        // 抽检制：deep link / 关键词触发模型复核入口（占位）
        return result
    }

    static func moderateLocally(_ text: String) -> ContentModerationResult {
        let lowercased = text.lowercased()
        var violations: [ContentModerationResult.ViolationCategory] = []
        var reasons: [String] = []
        
        if containsAny(lowercased, keywords: sexualKeywords) {
            violations.append(.sexual)
            reasons.append("包含低俗内容")
        }
        
        if containsAny(lowercased, keywords: violenceKeywords) {
            violations.append(.violence)
            reasons.append("包含过度暴力描述")
        }
        
        if containsAny(lowercased, keywords: selfHarmKeywords) {
            violations.append(.selfHarm)
            reasons.append("包含自残/自杀相关内容")
        }
        
        if containsAny(lowercased, keywords: hateKeywords) {
            violations.append(.hate)
            reasons.append("包含仇恨言论")
        }
        
        if containsAny(lowercased, keywords: illegalKeywords) {
            violations.append(.illegal)
            reasons.append("包含违法内容")
        }
        
        let isSafe = violations.isEmpty
        let reason = isSafe ? nil : reasons.joined(separator: "；")
        
        return ContentModerationResult(
            isSafe: isSafe,
            categories: violations,
            reason: reason
        )
    }
    
    /// 青少年模式下的额外过滤（屏蔽惊悚恐怖题材等）
    static func teenModeFilter(_ text: String) -> Bool {
        let teenRestrictedKeywords = [
            "gore", "explicit", "horror scene", "slasher",
            "血腥", "恐怖画面", "鬼故事细节", "血腥场面"
        ]
        let lowercased = text.lowercased()
        return !containsAny(lowercased, keywords: teenRestrictedKeywords)
    }
    
    // MARK: Private
    
    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        return keywords.contains { text.contains($0.lowercased()) }
    }
}
