import Foundation

// MARK: - AI Service Protocol
/// AI服务协议，方便 mock 测试和切换后端实现

protocol AIServiceProtocol {
    
    /// 生成故事开篇
    func generateOpening(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) async throws -> StoryGenerationResult
    
    /// 继续生成剧情
    func continueStory(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) async throws -> StoryGenerationResult
    
    /// 生成故事标题
    func generateTitle(for opening: String) async throws -> String
    
    /// 内容审核（云端）
    func moderateContent(_ text: String) async throws -> ContentModerationResult
    
    /// 生成角色描述
    func generateCharacterDetails(name: String, personality: String) async throws -> CharacterDetails

    // MARK: Streaming

    /// 流式生成故事开篇（SSE）。返回逐片的增量文本片段。
    func generateOpeningStreaming(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) -> AsyncThrowingStream<String, Error>

    /// 流式继续生成剧情（SSE）。返回逐片的增量文本片段。
    func continueStoryStreaming(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Generation Result

struct StoryGenerationResult {
    let content: String
    let choices: [StoryChoice]
    let sceneDescription: String?   // 场景描述，可用于图像生成
}

// MARK: - Content Moderation

struct ContentModerationResult {
    let isSafe: Bool
    let categories: [ViolationCategory]
    let reason: String?
    
    enum ViolationCategory: String, Codable {
        case violence        // 暴力
        case sexual          // 色情
        case hate            // 仇恨
        case political       // 政治敏感
        case selfHarm        // 自残/自杀
        case illegal         // 违法
    }
}

// MARK: - Character Details

struct CharacterDetails {
    let appearance: String
    let skills: String
    let background: String
}

// MARK: - AI Error

enum AIError: LocalizedError {
    case apiKeyMissing
    case networkError(Error)
    case invalidResponse
    case contentBlocked(reason: String)
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "AI API 密钥未配置"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .invalidResponse:
            return "AI 返回了无效响应"
        case .contentBlocked(let reason):
            return "内容审核未通过：\(reason)"
        case .timeout:
            return "AI 生成超时，请重试"
        case .unknown:
            return "发生未知错误"
        }
    }
}
