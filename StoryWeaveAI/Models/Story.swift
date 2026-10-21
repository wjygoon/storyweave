import Foundation
import SwiftData

// MARK: - Story Model
/// 故事主模型，使用 SwiftData 本地持久化存储

@Model
final class Story {
    @Attribute(.unique) var id: UUID
    var title: String
    var worldTemplate: String          // 世界观标识符
    var customWorldSetting: String?    // 自定义世界观描述
    var storyStyle: StoryStyle          // 故事风格
    var createdAt: Date
    var updatedAt: Date
    var lastPlayedAt: Date
    var isCompleted: Bool
    var playCount: Int

    // MARK: - Tomorrow's Chapter (P0-9: 数据预留，暂不实现推送)
    var nextChapterReady: Bool = false
    var nextChapterContent: String?
    var nextChapterPreview: String?
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var lastChapterPrepAt: Date?
    
    // MARK: Relationships
    @Relationship(deleteRule: .cascade, inverse: \StoryNode.story)
    var nodes: [StoryNode] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Character.stories)
    var characters: [Character] = []
    
    // MARK: Computed Properties
    var currentNode: StoryNode? {
        nodes.first(where: { $0.isCurrent })
    }
    
    var progress: Double {
        guard !nodes.isEmpty else { return 0 }
        let completedCount = nodes.filter { $0.isRead }.count
        return Double(completedCount) / Double(nodes.count)
    }

    /// 标题为空（AI 偶发返回空串）时的兜底显示名
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return (WorldTemplate.template(with: worldTemplate)?.name ?? "未知世界") + "奇遇"
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        worldTemplate: String,
        customWorldSetting: String? = nil,
        storyStyle: StoryStyle = .relaxed,
        characters: [Character] = []
    ) {
        self.id = id
        self.title = title
        self.worldTemplate = worldTemplate
        self.customWorldSetting = customWorldSetting
        self.storyStyle = storyStyle
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastPlayedAt = Date()
        self.isCompleted = false
        self.playCount = 1
        self.nextChapterReady = false
        self.reminderEnabled = false
        self.reminderHour = 20
        self.characters = characters
    }
}

// MARK: - Story Style Enum

enum StoryStyle: String, Codable, CaseIterable, Identifiable {
    case relaxed     // 轻松
    case serious     // 严肃
    case healing     // 治愈
    case mindBending // 烧脑
    case funny       // 搞笑
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .relaxed: return "轻松愉快"
        case .serious: return "严肃深沉"
        case .healing: return "治愈温暖"
        case .mindBending: return "烧脑悬疑"
        case .funny: return "搞笑幽默"
        }
    }
    
    var promptHint: String {
        switch self {
        case .relaxed: return "风格轻松愉快，对话幽默风趣"
        case .serious: return "风格严肃深沉，情节扣人心弦"
        case .healing: return "风格温暖治愈，充满希望和感动"
        case .mindBending: return "风格复杂烧脑，充满反转和悬念"
        case .funny: return "风格搞笑幽默，情节夸张有趣"
        }
    }
}

// MARK: - Story Node Model
/// 剧情节点，支持回溯和分支选择

@Model
final class StoryNode {
    @Attribute(.unique) var id: UUID
    @Relationship var story: Story?
    var parentNodeId: UUID?            // 父节点，nil 表示根节点
    var sequence: Int                  // 在故事中的顺序
    var content: String                // 剧情文本
    var sceneImageURL: String?         // 场景插图URL（付费）
    var choicesData: Data?             // 选择选项数组的JSON编码
    var selectedChoiceId: String?      // 用户选择的选项ID
    var isCurrent: Bool                // 是否为当前节点
    var isRead: Bool                   // 是否已读
    var createdAt: Date
    
    // MARK: Computed Properties
    var parentNode: StoryNode? {
        guard let parentId = parentNodeId, let story = story else { return nil }
        return story.nodes.first(where: { $0.id == parentId })
    }
    
    var choices: [StoryChoice] {
        get {
            guard let data = choicesData,
                  let decoded = try? JSONDecoder().decode([StoryChoice].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            choicesData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        id: UUID = UUID(),
        content: String,
        sequence: Int,
        parentNodeId: UUID? = nil,
        choices: [StoryChoice] = [],
        sceneImageURL: String? = nil
    ) {
        self.id = id
        self.content = content
        self.sequence = sequence
        self.parentNodeId = parentNodeId
        self.sceneImageURL = sceneImageURL
        self.choicesData = try? JSONEncoder().encode(choices)
        self.isCurrent = false
        self.isRead = false
        self.createdAt = Date()
    }
}

// MARK: - Story Choice

struct StoryChoice: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var previewHint: String?   // AI生成的后续预览（可选）
}
