import Foundation
import SwiftData

// MARK: - Character Model
/// 角色模型，支持自定义创建和AI辅助生成

@Model
final class Character {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarURL: String?
    var personality: String           // 性格描述
    var appearance: String?           // 外貌描述
    var skills: String?               // 技能描述
    var background: String?           // 背景故事
    var isAIGenerated: Bool
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var stories: [Story] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        personality: String,
        avatarURL: String? = nil,
        appearance: String? = nil,
        skills: String? = nil,
        background: String? = nil,
        isAIGenerated: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.avatarURL = avatarURL
        self.appearance = appearance
        self.skills = skills
        self.background = background
        self.isAIGenerated = isAIGenerated
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
