import Foundation
import SwiftUI

// MARK: - Story Creation ViewModel

@MainActor
final class StoryCreationViewModel: ObservableObject {
    
    // MARK: Input State
    @Published var selectedWorldTemplate: WorldTemplate?
    @Published var customWorldSetting: String = ""
    @Published var selectedStyle: StoryStyle = .relaxed
    @Published var protagonistName: String = ""
    @Published var protagonistPersonality: String = ""
    @Published var characters: [Character] = []
    
    // MARK: Creation Mode
    enum CreationMode {
        case quick      // 快速开局
        case custom     // 自定义创作
    }
    var mode: CreationMode = .quick
    
    // MARK: Generation State
    @Published var isGenerating: Bool = false
    @Published var generatedOpening: String?
    @Published var generatedChoices: [StoryChoice] = []
    @Published var generatedSceneDescription: String?
    @Published var errorMessage: String?
    
    // MARK: Completion
    @Published var createdStory: Story?
    @Published var createdRootNode: StoryNode?
    
    // MARK: Validation
    
    var canGenerate: Bool {
        guard selectedWorldTemplate != nil else { return false }
        
        switch mode {
        case .quick:
            return !protagonistName.trimmingCharacters(in: .whitespaces).isEmpty
        case .custom:
            return !customWorldSetting.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !protagonistName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    // MARK: Generate Opening
    
    func generateOpening() async {
        guard canGenerate else { return }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            let template = selectedWorldTemplate!
            let worldSetting = customWorldSetting.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customWorldSetting
            
            // 创建主角角色对象
            let protagonist = Character(
                name: protagonistName.trimmingCharacters(in: .whitespaces),
                personality: protagonistPersonality.isEmpty ? "勇敢而好奇" : protagonistPersonality
            )
            
            var allCharacters = characters
            allCharacters.insert(protagonist, at: 0)
            
            // 调用 AI 生成
            let result = try await AIServiceManager.shared.generateOpening(
                worldTemplate: template,
                customSetting: worldSetting,
                characters: allCharacters,
                style: selectedStyle
            )
            
            // 内容审核
            if AppConfig.Features.enableContentModeration {
                let moderation = ContentModerator.moderateLocally(result.content)
                if !moderation.isSafe {
                    throw AIError.contentBlocked(reason: moderation.reason ?? "内容不符合规范")
                }
            }
            
            generatedOpening = result.content
            generatedChoices = result.choices
            generatedSceneDescription = result.sceneDescription
            
            HapticManager.light()
            
        } catch let aiError as AIError {
            errorMessage = aiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    // MARK: Confirm Creation
    
    func confirmCreation() async {
        guard let template = selectedWorldTemplate,
              let opening = generatedOpening else { return }
        
        do {
            // 生成标题（AI 偶发返回空串或请求失败时使用本地兜底标题）
            var title = ((try? await AIServiceManager.shared.generateTitle(for: opening)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'《》“”"))
            if title.isEmpty {
                let heroName = protagonistName.trimmingCharacters(in: .whitespaces)
                title = "\(heroName)的\(template.name)之旅"
            }

            // 创建故事
            let story = Story(
                title: title,
                worldTemplate: template.id,
                customWorldSetting: customWorldSetting.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customWorldSetting,
                storyStyle: selectedStyle
            )
            
            // 创建根节点
            let rootNode = StoryNode(
                content: opening,
                sequence: 0,
                choices: generatedChoices,
                sceneImageURL: nil
            )
            
            try DataManager.shared.createStory(story)
            try DataManager.shared.addNode(rootNode, to: story)
            
            // 添加角色到故事
            let protagonist = Character(
                name: protagonistName,
                personality: protagonistPersonality.isEmpty ? "勇敢而好奇" : protagonistPersonality
            )
            story.characters.append(protagonist)
            DataManager.shared.createCharacter(protagonist)
            
            // 记录创建次数
            UserPreferences.shared.recordCreation()
            
            createdStory = story
            createdRootNode = rootNode
            
            HapticManager.success()
            
        } catch {
            errorMessage = "创建故事失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: Add Character
    
    func addCharacter(name: String, personality: String) {
        let char = Character(name: name, personality: personality)
        characters.append(char)
    }
    
    func removeCharacter(_ character: Character) {
        characters.removeAll { $0.id == character.id }
    }
    
    // MARK: Reset
    
    func reset() {
        selectedWorldTemplate = nil
        customWorldSetting = ""
        selectedStyle = .relaxed
        protagonistName = ""
        protagonistPersonality = ""
        characters.removeAll()
        generatedOpening = nil
        generatedChoices.removeAll()
        errorMessage = nil
        createdStory = nil
        createdRootNode = nil
    }
}
