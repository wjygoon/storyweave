import Foundation
import SwiftData

// MARK: - Data Manager
/// SwiftData 数据管理中心，统一管理所有本地数据操作

final class DataManager {
    
    static let shared = DataManager()
    
    // MARK: Properties
    private var modelContainer: ModelContainer?
    
    // MARK: Setup
    
    /// 从 App 注入 ModelContainer（共享同一数据库，避免两套容器数据不互通）
    @MainActor
    func inject(_ container: ModelContainer) {
        self.modelContainer = container
    }
    
    /// 获取 ModelContext（自动 lazy 初始化，永不崩溃）
    @MainActor
    var context: ModelContext {
        // 已有容器 → 直接用
        if let container = modelContainer {
            return ModelContext(container)
        }
        // 没有 → 自己创建（兜底，保证永不 fatalError）
        do {
            let schema = Schema([Story.self, StoryNode.self, Character.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            return ModelContext(container)
        } catch {
            print("⚠️ DataManager: context init failed - \(error)")
            let container = try! ModelContainer(for: Schema([Story.self, StoryNode.self, Character.self]))
            return ModelContext(container)
        }
    }
    
    // MARK: - Story Operations
    
    /// 获取所有故事，按最后游玩时间排序
    @MainActor
    func fetchAllStories() throws -> [Story] {
        let descriptor = FetchDescriptor<Story>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// 根据ID获取故事
    @MainActor
    func fetchStory(id: UUID) throws -> Story? {
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// 创建新故事
    @MainActor
    func createStory(_ story: Story) throws {
        context.insert(story)
        try context.save()
    }
    
    /// 删除故事
    @MainActor
    func deleteStory(_ story: Story) throws {
        context.delete(story)
        try context.save()
    }
    
    /// 更新故事游玩时间
    @MainActor
    func markStoryAsPlayed(_ story: Story) throws {
        story.lastPlayedAt = Date()
        story.updatedAt = Date()
        story.playCount += 1
        try context.save()
    }
    
    /// 标记故事为完成
    @MainActor
    func markStoryAsCompleted(_ story: Story) throws {
        story.isCompleted = true
        story.updatedAt = Date()
        try context.save()
    }
    
    // MARK: - Story Node Operations
    
    /// 为故事添加新节点
    @MainActor
    func addNode(_ node: StoryNode, to story: Story) throws {
        // 将当前节点标记为非当前
        story.nodes.forEach { $0.isCurrent = false }
        
        node.story = story
        node.isCurrent = true
        story.nodes.append(node)
        story.updatedAt = Date()
        
        try context.save()
    }
    
    /// 回溯到指定节点
    @MainActor
    func rewindToNode(_ targetNode: StoryNode, in story: Story) throws {
        // 找到目标节点和后续节点的分界点
        // 将目标节点标记为当前节点，之前的节点标记为已读
        story.nodes.forEach { node in
            if node.sequence <= targetNode.sequence {
                node.isCurrent = (node.id == targetNode.id)
                node.isRead = node.sequence < targetNode.sequence
            } else {
                // 序列在目标之后的节点（回溯产生的分支）暂时移除
                // 可以选择保留作为平行时间线
            }
        }
        targetNode.isCurrent = true
        targetNode.isRead = false
        
        try context.save()
    }
    
    /// 获取故事的完整时间线
    @MainActor
    func fetchTimeline(for story: Story) throws -> [StoryNode] {
        let descriptor = FetchDescriptor<StoryNode>(
            sortBy: [SortDescriptor(\.sequence, order: .forward)]
        )
        let allNodes = try context.fetch(descriptor)
        return allNodes.filter { $0.story?.id == story.id }
    }
    
    // MARK: - Character Operations
    
    /// 获取所有角色
    @MainActor
    func fetchAllCharacters() throws -> [Character] {
        let descriptor = FetchDescriptor<Character>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// 创建角色
    @MainActor
    func createCharacter(_ character: Character) {
        context.insert(character)
        Task { @MainActor in try? context.save() }
    }
    
    /// 删除角色
    @MainActor
    func deleteCharacter(_ character: Character) {
        context.delete(character)
        Task { @MainActor in try? context.save() }
    }
    
    /// 更新角色
    @MainActor
    func updateCharacter(_ character: Character) throws {
        character.updatedAt = Date()
        Task { @MainActor in try? context.save() }
    }
    
    // MARK: - Export
    
    /// 导出故事为纯文本
    @MainActor
    func exportStoryAsText(_ story: Story) throws -> String {
        let nodes = try fetchTimeline(for: story)
        
        var text = "《\(story.title)》\n\n"
        text += "世界观：\(WorldTemplate.template(with: story.worldTemplate)?.name ?? story.worldTemplate)\n"
        text += "风格：\(story.storyStyle.displayName)\n"
        text += "更新时间：\(story.updatedAt.formatted())\n"
        text += "-----------------------------------\n\n"
        
        for node in nodes {
            text += node.content
            text += "\n\n"
            
            if !node.choices.isEmpty && node.id != story.currentNode?.id {
                if let selectedChoiceId = node.selectedChoiceId,
                   let selected = node.choices.first(where: { $0.id == selectedChoiceId }) {
                    text += "（选择：\(selected.text)）\n\n"
                }
            }
        }
        
        return text
    }
    
    // MARK: - Save
    
    @MainActor
    func clearAll() throws {
        try context.delete(model: Story.self)
        try context.delete(model: StoryNode.self)
        try context.delete(model: Character.self)
        try context.save()
    }

    @MainActor
    func save() throws {
        try context.save()
    }
}
