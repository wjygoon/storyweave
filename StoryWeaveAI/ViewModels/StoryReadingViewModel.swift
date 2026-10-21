import Foundation
import SwiftUI

// MARK: - Story Reading ViewModel

@MainActor
final class StoryReadingViewModel: ObservableObject {
    
    // MARK: Story State
    @Published var story: Story?
    @Published var nodes: [StoryNode] = []
    @Published var currentNode: StoryNode?
    @Published var isGenerating: Bool = false
    @Published var generationError: String?
    @Published var lastChoice: StoryChoice?
    
    // MARK: Timeline (for 回溯)
    @Published var showTimeline: Bool = false
    
    // MARK: Scene Image
    @Published var sceneImageData: Data?
    @Published var isGeneratingImage: Bool = false
    @Published var pendingSceneDescription: String? = nil
    
    // MARK: Init / Setup
    
    func loadStory(_ story: Story) async {
        self.story = story
        
        do {
            nodes = try DataManager.shared.fetchTimeline(for: story)
            currentNode = nodes.first(where: { $0.isCurrent }) ?? nodes.last
            
            // 标记之前的节点为已读
            if let current = currentNode {
                for node in nodes where node.sequence < current.sequence {
                    node.isRead = true
                }
            }
            
            try DataManager.shared.markStoryAsPlayed(story)
        } catch {
            generationError = "加载故事失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: Make Choice & Continue Story
    
    func makeChoice(_ choice: StoryChoice) async {
        lastChoice = choice
        guard let story = story,
              let current = currentNode else { return }
        
        isGenerating = true
        generationError = nil

        // ⑥ 12 秒兜底：超时触发友好错误 + 提示重 roll
        let fallbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConfig.Limits.aiFallback * 1_000_000_000))
            if isGenerating {
                generationError = "AI 正在构思中…试试重 roll，或稍后回来"
            }
        }
        defer { fallbackTask.cancel() }

        do {
            // 更新当前节点的选择记录
            current.selectedChoiceId = choice.id
            current.isRead = true
            
            // 获取故事历史（上下文）
            let history = Array(nodes.suffix(8))
            
            // 调用 AI 继续生成
            let result = try await AIServiceManager.shared.continueStory(
                currentNode: current,
                choice: choice,
                storyHistory: history,
                style: story.storyStyle
            )
            
            // 内容审核
            if AppConfig.Features.enableContentModeration {
                let moderation = ContentModerator.moderateLocally(result.content)
                if !moderation.isSafe {
                    throw AIError.contentBlocked(reason: moderation.reason ?? "内容不符合规范")
                }
            }
            
            // 如果是青少年模式，额外过滤
            if UserPreferences.shared.enableTeenMode {
                let teenPassed = ContentModerator.teenModeFilter(result.content)
                if !teenPassed {
                    throw AIError.contentBlocked(reason: "内容不符合青少年模式要求")
                }
            }
            
            // 创建新节点
            let newNode = StoryNode(
                content: result.content,
                sequence: current.sequence + 1,
                parentNodeId: current.id,
                choices: result.choices
            )
            
            // 保存到数据层
            try DataManager.shared.addNode(newNode, to: story)
            
            // 刷新节点列表
            nodes = try DataManager.shared.fetchTimeline(for: story)
            currentNode = nodes.first(where: { $0.id == newNode.id }) ?? newNode
            
            // 缓存 sceneDescription 供用户手动点击时也能生成
            if let sceneDesc = result.sceneDescription {
                self.pendingSceneDescription = sceneDesc
            }

            // 自动生成场景图像（付费功能，可选）
            if AppConfig.Features.enableSceneImages,
               let sceneDesc = result.sceneDescription {
                Task { @MainActor [weak self] in
                    await self?.generateSceneImageData(description: sceneDesc, for: newNode)
                }
            }
            
            HapticManager.light()
            
        } catch let aiError as AIError {
            generationError = aiError.localizedDescription
        } catch {
            generationError = "生成失败：\(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    // MARK: Generate Scene Image
    

    /// 用户手动点击按钮触发 — 自动用当前 node + 最近的 sceneDescription
    func generateSceneImage() async {
        guard let currentNode, !isGeneratingImage else { return }
        let desc = pendingSceneDescription ?? String(currentNode.content.prefix(200))
        await generateSceneImageData(description: desc, for: currentNode)
    }
    func generateSceneImageData(description: String, for node: StoryNode) async {
        isGeneratingImage = true
        defer { isGeneratingImage = false }
        
        do {
            let imageData = try await AIServiceManager.shared.generateSceneImageData(description: description)
            sceneImageData = imageData
            node.sceneImageURL = UUID().uuidString + ".png"
            try DataManager.shared.save()
            
        } catch {
            print("Image generation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: Rewind
    
    func rewindTo(node: StoryNode) async {
        guard let story = story else { return }
        
        do {
            try DataManager.shared.rewindToNode(node, in: story)
            nodes = try DataManager.shared.fetchTimeline(for: story)
            currentNode = nodes.first(where: { $0.id == node.id })
            
            sceneImageData = nil
            pendingSceneDescription = nil
            showTimeline = false
            
            HapticManager.medium()
        } catch {
            generationError = "回溯失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: Export
    
    func exportStory() -> String? {
        guard let story = story else { return nil }
        do {
            return try DataManager.shared.exportStoryAsText(story)
        } catch {
            return nil
        }
    }
    
    // MARK: Progress
    
    var progressText: String {
        guard story != nil else { return "" }
        let completed = nodes.filter { $0.isRead }.count
        let total = nodes.count
        return "\(completed)/\(total) 节点"
    }
    
    var timelineMarkers: [Int] {
        return nodes.map { $0.sequence }
    }
}
