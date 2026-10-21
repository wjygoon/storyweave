import Foundation
import SwiftData
import SwiftUI

// MARK: - Home ViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    
    @Published var stories: [Story] = []
    @Published var recentStoryNodes: [UUID: [StoryNode]] = [:]
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // 推荐世界观（本地 + 屏蔽过滤）
    private var blockedIDs: Set<String> { BlockManager.shared.blockedSourceIDs }

    var recommendedWorldTemplates: [WorldTemplate] {
        WorldTemplate.all.filter { !$0.isPremium && !blockedIDs.contains($0.id) }
    }

    var premiumWorldTemplates: [WorldTemplate] {
        WorldTemplate.all.filter { $0.isPremium && !blockedIDs.contains($0.id) }
    }
    
    // MARK: Lifecycle
    
    func loadStories() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let allStories = try DataManager.shared.fetchAllStories()
            stories = allStories
            
            // 预加载每个故事的当前节点信息
            for story in stories {
                let nodes = try DataManager.shared.fetchTimeline(for: story)
                recentStoryNodes[story.id] = nodes
            }
        } catch {
            self.error = "加载故事失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: Story Operations
    
    func deleteStory(_ story: Story) async {
        do {
            try DataManager.shared.deleteStory(story)
            await loadStories()
            HapticManager.success()
        } catch {
            self.error = "删除失败：\(error.localizedDescription)"
        }
    }
    
    func canCreateNewStory(isPremium: Bool) -> Bool {
        return UserPreferences.shared.canCreateNewStory(isPremium: isPremium)
    }
    
    var remainingCreationsText: String {
        let prefs = UserPreferences.shared
        let remaining = AppConfig.Limits.freeDailyCreations - prefs.todayCreationCount
        return "今日剩余 \(max(0, remaining)) 次创建机会"
    }
    
    var hasStories: Bool {
        !stories.isEmpty
    }
    
    // MARK: Premium Wall Check
    
    func shouldShowPaywall(for template: WorldTemplate, isPremium: Bool) -> Bool {
        return template.isPremium && !isPremium
    }
}
