import Foundation

// MARK: - DeepSeek Service
/// DeepSeek V3 API - 国内最好的开源大模型，兼容 OpenAI 格式
/// 官网: https://platform.deepseek.com/

final class DeepSeekService: AIServiceProtocol {
    
    static var shared: DeepSeekService {
        let key = Secrets.value(for: "DEEPSEEK_API_KEY") ?? ""
        return DeepSeekService(apiKey: key, proxy: nil)
    }
    
    private let apiKey: String
    private let proxy: ProxyConfig?
    private let baseURL = "https://api.deepseek.com/v1"
    private let model = "deepseek-chat"
    
    init(apiKey: String, proxy: ProxyConfig?) {
        self.apiKey = apiKey
        self.proxy = proxy
    }
    
    // MARK: AIServiceProtocol
    
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
        为以下中文故事开篇生成一个吸引人的标题（10字以内）。只输出标题，不要任何解释和引号。
        
        内容：\(opening.prefix(500))
        """
        return try await generateRawContent(prompt: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func moderateContent(_ text: String) async throws -> ContentModerationResult {
        return ContentModerator.moderateLocally(text)
    }
    
    func generateCharacterDetails(name: String, personality: String) async throws -> CharacterDetails {
        let prompt = """
        为角色 "\(name)"（性格：\(personality)）生成设定。返回JSON：
        {"appearance":"外貌（30字内）","skills":"技能（20字内）","background":"背景（80字内）"}
        """
        let raw = try await generateRawContent(prompt: prompt)
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return CharacterDetails(
                appearance: json["appearance"] ?? "神秘的外表",
                skills: json["skills"] ?? "未知",
                background: json["background"] ?? "一个谜一样的人"
            )
        }
        return CharacterDetails(appearance: "神秘的外表", skills: "未知", background: "一个谜")
    }
    
    // MARK: Private
    
    private func generateContent(prompt: String) async throws -> StoryGenerationResult {
        let raw = try await generateRawContent(prompt: prompt)

        // 输出本地 re-scan（三层审核第三层，零额外成本）
        let scan = ContentModerator.validateOutput(raw)
        if !scan.isSafe {
            throw AIError.contentBlocked(reason: scan.reason ?? "生成内容未通过安全审核，请重试")
        }

        // 尝试解析 JSON
        if let result = try? parseGenerationResponse(raw) {
            return result
        }
        
        // fallback: 尽量从 raw 里提取 content 文本，实在不行 strip JSON 壳
        let cleanContent = extractContentFromRaw(raw)
        return StoryGenerationResult(
            content: cleanContent,
            choices: defaultChoices(),
            sceneDescription: nil
        )
    }
    
    private func generateRawContent(prompt: String) async throws -> String {
        guard !apiKey.contains("YOUR_") && !apiKey.isEmpty else {
            throw AIError.apiKeyMissing
        }
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": """
             你是一个专业的中文互动故事编剧。你的任务是生成引人入胜的故事内容和分支选项。
             
             重要规则：
             - 严格遵守JSON格式输出
             - 不要生成任何违规内容（色情、暴力、政治等）
             - 故事要有吸引力，人物性格一致
             - 选项要导向不同的发展方向
             - 符合12+年龄分级
             """],
            ["role": "user", "content": prompt]
        ]
        
        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.85,
            "max_tokens": 2048,
            "response_format": ["type": "json_object"]
        ]
        
        return try await makeRequest(endpoint: "/chat/completions", payload: payload)
    }
    
    private func makeRequest(endpoint: String, payload: [String: Any]) async throws -> String {
        let url = URL(string: baseURL + endpoint)!
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let sessionConfig = URLSessionConfiguration.default
        if let proxy = proxy {
            proxy.configureSession(sessionConfig)
        }
        let session = URLSession(configuration: sessionConfig)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = AppConfig.Limits.aiTimeout
        
        let (data, response) = try await session.data(for: request)
        
        guard let resp = response as? HTTPURLResponse, resp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.networkError(NSError(domain: body, code: code))
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    // MARK: Prompt Builders (复用 Gemini 的 prompt)
    
    private func buildOpeningPrompt(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) -> String {
        let characterInfo = characters.map { "- \($0.name)：\($0.personality)" }.joined(separator: "\n")
        let world = customSetting ?? worldTemplate.settingPrompt
        let hooks = worldTemplate.openingHooks
        
        return """
        根据以下设定，创作一个引人入胜的中文故事开篇。
        
        世界观：\(world)
        故事风格：\(style.displayName)
        角色：\(characterInfo.isEmpty ? "- 主角" : characterInfo)
        
        可选开局：\(hooks.prefix(2).joined(separator: " 或 "))
        
        请以JSON格式返回：
        {"content":"开篇正文（200-400字）","choices":[{"text":"选项1","previewHint":"预览"},{"text":"选项2","previewHint":"预览"},{"text":"选项3","previewHint":"预览"},{"text":"选项4","previewHint":"预览"}],"sceneDescription":"场景视觉描述（可选）"}
        """
    }
    
    private func buildContinuePrompt(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) -> String {
        let history = storyHistory.suffix(5).enumerated().map { idx, node in
            "[\(idx+1)] \(node.content.prefix(150))"
        }.joined(separator: "\n\n")
        
        let choiceText = choice != nil ? "玩家选择了：\(choice!.text)" : "继续剧情"
        
        return """
        请继续以下中文故事，自然承接上文。
        
        故事风格：\(style.displayName)
        
        故事历史：
        \(history)
        
        \(choiceText)
        
        以JSON返回：
        {"content":"续写正文（150-300字）","choices":[{"text":"选项1","previewHint":"预览"},{"text":"选项2","previewHint":"预览"},{"text":"选项3","previewHint":"预览"},{"text":"选项4","previewHint":"预览"}],"sceneDescription":"场景描述（可选）"}
        """
    }
    
    // MARK: Response Parsing

    private func parseGenerationResponse(_ raw: String) throws -> StoryGenerationResult {
        let text = extractCleanJSON(from: raw)

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            throw AIError.invalidResponse
        }

        let choicesArray = json["choices"] as? [[String: Any]] ?? []
        let choices = choicesArray.prefix(AppConfig.Limits.choiceCount).map { dict in
            StoryChoice(
                text: (dict["text"] as? String ?? "继续...").cleanText(),
                previewHint: (dict["previewHint"] as? String)?.cleanText()
            )
        }

        return StoryGenerationResult(
            content: content.cleanText(),
            choices: choices.isEmpty ? defaultChoices() : choices,
            sceneDescription: (json["sceneDescription"] as? String)?.cleanText()
        )
    }

    /// 从模型输出中健壮提取第一个合法 JSON 对象
    private func extractCleanJSON(from raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 剥掉 markdown 代码块 ```json ... ```
        if let open = text.range(of: "```"),
           let close = text.range(of: "```", range: open.upperBound..<text.endIndex) {
            text = String(text[open.upperBound..<close.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("json") { text.removeFirst(4); text = text.trimmingCharacters(in: .whitespaces) }
        }

        // 2. 第一个 { 到最后一个 } 之间
        guard let first = text.firstIndex(of: "{"),
              let last = text.lastIndex(of: "}") else { return text }
        text = String(text[first...last])

        // 3. 清理残留标记
        for token in ["[{type:json}]", "{type:json}", "[JSON]", "<json>", "</json>"] {
            text = text.replacingOccurrences(of: token, with: "")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// parseGenerationResponse 失败时的最后保底：
    /// 尝试从非标准 JSON 输出里提取 content 文本；或剥离 JSON 壳
    /// parseGenerationResponse 失败时的最后保底：
    /// 尝试从非标准 JSON 输出里提取 content 文本；或剥离 JSON 壳
    /// parseGenerationResponse 失败时的最后保底：
    /// 尝试从非标准 JSON 输出里提取 content 文本；或剥离 JSON 壳
    /// parseGenerationResponse 失败时的最后保底
    private func extractContentFromRaw(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = text
        if let open = cleaned.range(of: "```"),
           let close = cleaned.range(of: "```", range: open.upperBound..<cleaned.endIndex) {
            cleaned = String(cleaned[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("json") { cleaned.removeFirst(4); cleaned = cleaned.trimmingCharacters(in: .whitespaces) }
        }
        if let first = cleaned.firstIndex(of: "{"),
           let last = cleaned.lastIndex(of: "}") {
            let jsonCandidate = String(cleaned[first...last])
            if let data = jsonCandidate.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? String {
                return content.cleanText()
            }
        }
        var stripped = cleaned
        stripped = stripped.replacingOccurrences(of: "[{}\\[\\]\"]", with: "", options: .regularExpression)
        stripped = stripped.replacingOccurrences(of: "null", with: "")
        stripped = stripped.replacingOccurrences(of: "^[,\\s]+|[,\\s]+$", with: "", options: .regularExpression)
        if stripped.count < 20 {
            if let idx = cleaned.firstIndex(where: { $0.isPunctuation || $0.isWhitespace }),
               cleaned.distance(from: cleaned.startIndex, to: idx) > 10 {
                let after = cleaned[idx...]
                let badChars = ["\"", ",", " ", "\\", "{", "[", "]", "}"]
                if let realStart = after.firstIndex(where: { !badChars.contains(String($0)) }) {
                    return String(after[realStart...]).cleanText()
                }
            }
        }
        return stripped.cleanText()
    }

    // MARK: Streaming (SSE)

    func generateOpeningStreaming(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        let prompt = buildOpeningPrompt(
            worldTemplate: worldTemplate, customSetting: customSetting,
            characters: characters, style: style
        )
        return makeStreamingRequest(prompt: prompt)
    }

    func continueStoryStreaming(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        let prompt = buildContinuePrompt(
            currentNode: currentNode, choice: choice,
            storyHistory: storyHistory, style: style
        )
        return makeStreamingRequest(prompt: prompt)
    }

    /// SSE 核心：POST /chat/completions + stream:true，逐行解析 data: 事件
    private func makeStreamingRequest(prompt: String) -> AsyncThrowingStream<String, Error> {
        guard !apiKey.contains("YOUR_") && !apiKey.isEmpty else {
            return AsyncThrowingStream { cont in cont.finish(throwing: AIError.apiKeyMissing) }
        }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages: [[String: Any]] = [
                        ["role": "system", "content": "你是一个专业的中文互动故事编剧。严格遵守JSON格式输出，不要生成违规内容，符合12+年龄分级。"],
                        ["role": "user", "content": prompt]
                    ]
                    let payload: [String: Any] = [
                        "model": model, "messages": messages,
                        "temperature": 0.85, "max_tokens": 2048, "stream": true
                    ]
                    let url = URL(string: baseURL + "/chat/completions")!
                    let jsonData = try JSONSerialization.data(withJSONObject: payload)
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = jsonData
                    request.timeoutInterval = 30

                    let (stream, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                        continuation.finish(throwing: AIError.networkError(NSError(domain: "HTTP \(code)", code: code)))
                        return
                    }

                    var buffer = ""
                    for try await byte in stream {
                        guard let chunk = String(data: Data([byte]), encoding: .utf8) else { continue }
                        buffer += chunk
                        while let range = buffer.range(of: "\n\n") {
                            let event = String(buffer[..<range.lowerBound])
                            buffer.removeSubrange(..<range.upperBound)
                            await Task.yield()
                            for line in event.components(separatedBy: "\n") {
                                guard line.hasPrefix("data: ") else { continue }
                                let data = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                                if data == "[DONE]" { continuation.finish(); return }
                                if let json = data.data(using: .utf8),
                                   let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                                   let choices = obj["choices"] as? [[String: Any]],
                                   let first = choices.first,
                                   let delta = first["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    private func defaultChoices() -> [StoryChoice] {
        return [
            StoryChoice(text: "继续这个方向", previewHint: "顺着剧情发展"),
            StoryChoice(text: "尝试不同的方式", previewHint: "换个思路"),
            StoryChoice(text: "等待观察", previewHint: "静观其变"),
            StoryChoice(text: "冒险一试", previewHint: "勇敢向前")
        ]
    }
}

private extension String {
    func cleanText() -> String {
        var s = components(separatedBy: .controlCharacters).joined()
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
