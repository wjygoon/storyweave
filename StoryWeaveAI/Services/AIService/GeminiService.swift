import Foundation

// MARK: - Gemini AI Service
/// 使用 Google Gemini API 进行剧情生成

final class GeminiService: AIServiceProtocol {
    
    static let shared = GeminiService()
    
    // MARK: Properties
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let modelName = "gemini-1.5-pro"
    
    // MARK: - Public API
    
    func generateOpening(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        
        let prompt = buildOpeningPrompt(
            worldTemplate: worldTemplate,
            customSetting: customSetting,
            characters: characters,
            style: style
        )
        
        return try await generateContent(prompt: prompt)
    }
    
    func continueStory(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        
        let prompt = buildContinuePrompt(
            currentNode: currentNode,
            choice: choice,
            storyHistory: storyHistory,
            style: style
        )
        
        return try await generateContent(prompt: prompt)
    }
    
    func generateTitle(for opening: String) async throws -> String {
        let prompt = """
        为以下故事开篇生成一个吸引人的中文标题（10字以内）。
        只输出标题，不要任何解释。
        
        开篇内容：
        \(opening.prefix(500))
        """
        
        let result = try await generateContentRaw(prompt: prompt)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"「」『』"))
    }
    
    func moderateContent(_ text: String) async throws -> ContentModerationResult {
        // 先做本地检查
        let localResult = ContentModerator.moderateLocally(text)
        if !localResult.isSafe {
            return localResult
        }
        
        // 再做云端AI审核（可选，付费功能）
        let prompt = """
        作为内容审核员，请检查以下文本是否包含违规内容。
        违规类别：暴力、色情、仇恨、政治敏感、自残、违法。
        以JSON格式返回：{"is_safe": true/false, "categories": [], "reason": ""}
        
        待审核文本：
        \(text.prefix(1000))
        """
        
        let raw = try await generateContentRaw(prompt: prompt)
        return try parseModerationResponse(raw)
    }
    
    func generateCharacterDetails(name: String, personality: String) async throws -> CharacterDetails {
        let prompt = """
        为角色 "\(name)"（性格：\(personality)）生成详细设定。
        返回以下JSON格式（只输出JSON）：
        {
          "appearance": "外貌描述（50字以内）",
          "skills": "擅长的技能（30字以内）",
          "background": "背景故事（100字以内）"
        }
        """
        
        let raw = try await generateContentRaw(prompt: prompt)
        
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return CharacterDetails(
                appearance: "神秘的外表",
                skills: "未知",
                background: "一个谜一样的人"
            )
        }
        
        return CharacterDetails(
            appearance: json["appearance"] ?? "神秘的外表",
            skills: json["skills"] ?? "未知",
            background: json["background"] ?? "一个谜一样的人"
        )
    }
    
    // MARK: - Private API
    
    private func generateContent(prompt: String) async throws -> StoryGenerationResult {
        let raw = try await generateContentRaw(prompt: prompt)
        
        // 尝试解析JSON格式响应
        if let result = try? parseGenerationResponse(raw) {
            return result
        }
        
        // 如果不是JSON，尝试从纯文本中提取
        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let choices = generateDefaultChoices()
        
        return StoryGenerationResult(
            content: content,
            choices: choices,
            sceneDescription: nil
        )
    }
    
    private func generateContentRaw(prompt: String) async throws -> String {
        guard !AppConfig.API.geminiKey.contains("YOUR_") else {
            throw AIError.apiKeyMissing
        }
        
        let urlString = "\(baseURL)/models/\(modelName):generateContent?key=\(AppConfig.API.geminiKey)"
        guard let url = URL(string: urlString) else {
            throw AIError.invalidResponse
        }
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.8,
                "maxOutputTokens": 2048,
                "responseMimeType": "application/json"
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = AppConfig.Limits.aiTimeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIError.networkError(NSError(domain: errorBody, code: httpResponse.statusCode))
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                throw AIError.invalidResponse
            }
            
            return text
            
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }
    
    // MARK: - Prompt Builders
    
    private func buildOpeningPrompt(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) -> String {
        let characterInfo = characters.map { char in
            "- \(char.name)：\(char.personality)\(char.appearance != nil ? "，外貌：\(char.appearance!)" : "")"
        }.joined(separator: "\n")
        
        let world = customSetting ?? worldTemplate.settingPrompt
        let hooks = worldTemplate.openingHooks
        
        return """
        你是一个专业的互动故事编剧。请根据以下设定创作一个引人入胜的故事开篇。
        
        世界观设定：\(world)
        故事风格：\(style.displayName)（\(style.promptHint)）
        
        主要角色：
        \(characterInfo.isEmpty ? "- 主角（玩家扮演）" : characterInfo)
        
        可选的开局hook（任选其一或自行发挥）：
        \(hooks.prefix(3).map { "· \($0)" }.joined(separator: "\n"))
        
        请严格以以下JSON格式返回（不要任何额外解释）：
        {
          "content": "开篇剧情正文（300-500字，第一人称或第三人称叙述）",
          "choices": [
            {"text": "选项1的内容", "previewHint": "选择后的简短预览（15字内）"},
            {"text": "选项2的内容", "previewHint": "选择后的简短预览（15字内）"},
            {"text": "选项3的内容", "previewHint": "选择后的简短预览（15字内）"},
            {"text": "选项4的内容", "previewHint": "选择后的简短预览（15字内）"}
          ],
          "sceneDescription": "这个场景的视觉描述（用于AI生成插图，30字以内）"
        }
        
        要求：
        1. 剧情要有吸引力，结尾处留有悬念
        2. 选项要各有特色，导向不同的发展方向
        3. 符合12+年龄分级，避免不当内容
        """
    }
    
    private func buildContinuePrompt(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) -> String {
        let historyText = storyHistory.suffix(5).enumerated().map { index, node in
            let marker = node.id == currentNode.id ? "【当前】" : ""
            return "\(marker)[\(index + 1)] \(node.content.prefix(200))"
        }.joined(separator: "\n\n")
        
        let choiceText = choice != nil ? "玩家选择了：\(choice!.text)" : "玩家将继续探索"
        
        return """
        你是一个专业的互动故事编剧。请继续以下故事。
        
        故事风格：\(style.displayName)
        
        故事历史（最近几段）：
        \(historyText)
        
        \(choiceText)
        
        请严格以以下JSON格式返回：
        {
          "content": "继续的剧情正文（200-400字）",
          "choices": [
            {"text": "选项1", "previewHint": "预览"},
            {"text": "选项2", "previewHint": "预览"},
            {"text": "选项3", "previewHint": "预览"},
            {"text": "选项4", "previewHint": "预览"}
          ],
          "sceneDescription": "当前场景的视觉描述（可选）"
        }
        
        要求：
        1. 剧情要连贯，自然承接上文
        2. 保持角色性格一致性
        3. 选项要推动剧情向不同方向发展
        4. 适当埋下伏笔，制造悬念
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseGenerationResponse(_ raw: String) throws -> StoryGenerationResult {
        // 尝试从markdown代码块中提取JSON
        var text = raw
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            text = String(text[start.upperBound..<end.lowerBound])
        } else if let start = text.range(of: "```"),
                  let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            text = String(text[start.upperBound..<end.lowerBound])
        }
        
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }
        
        guard let content = json["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        let choicesArray = json["choices"] as? [[String: Any]] ?? []
        let choices = choicesArray.prefix(AppConfig.Limits.choiceCount).map { dict -> StoryChoice in
            StoryChoice(
                text: dict["text"] as? String ?? "继续...",
                previewHint: dict["previewHint"] as? String
            )
        }
        
        let sceneDescription = json["sceneDescription"] as? String
        
        let finalChoices = choices.isEmpty ? generateDefaultChoices() : choices
        
        return StoryGenerationResult(
            content: content,
            choices: finalChoices,
            sceneDescription: sceneDescription
        )
    }
    
    private func parseModerationResponse(_ raw: String) throws -> ContentModerationResult {
        var text = raw
        if let startRange = text.range(of: "{"),
           let endRange = text.range(of: "}") {
            text = String(text[startRange.lowerBound...endRange.lowerBound])
        }
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 解析失败，默认安全
            return ContentModerationResult(isSafe: true, categories: [], reason: nil)
        }
        
        let isSafe = json["is_safe"] as? Bool ?? true
        let categoriesRaw = json["categories"] as? [String] ?? []
        let reason = json["reason"] as? String
        
        let categories = categoriesRaw.compactMap { ContentModerationResult.ViolationCategory(rawValue: $0) }
        
        return ContentModerationResult(
            isSafe: isSafe,
            categories: categories,
            reason: reason
        )
    }
    
    private func generateDefaultChoices() -> [StoryChoice] {
        return [
            StoryChoice(text: "继续这个方向", previewHint: "顺着剧情发展"),
            StoryChoice(text: "尝试不同的方式", previewHint: "换个思路"),
            StoryChoice(text: "等待观察", previewHint: "静观其变")
        ]
    }

    // MARK: Streaming fallback — Gemini 暂不支持 SSE，异步拉取整段后一次 emit

    func generateOpeningStreaming(
        worldTemplate: WorldTemplate, customSetting: String?,
        characters: [Character], style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await generateOpening(
                        worldTemplate: worldTemplate, customSetting: customSetting,
                        characters: characters, style: style
                    )
                    continuation.yield(result.content)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    func continueStoryStreaming(
        currentNode: StoryNode, choice: StoryChoice?,
        storyHistory: [StoryNode], style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await continueStory(
                        currentNode: currentNode, choice: choice,
                        storyHistory: storyHistory, style: style
                    )
                    continuation.yield(result.content)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}
