import Foundation

// MARK: - Volcengine Ark Service (豆包)
/// 火山引擎方舟平台 - 字节跳动豆包大模型
/// 文档: https://www.volcengine.com/docs/82379

final class ArkService: AIServiceProtocol {
    
    static var shared: ArkService {
        let key = Secrets.value(for: "ARK_API_KEY") ?? ""
        return ArkService(apiKey: key, proxy: nil)
    }
    
    private let apiKey: String
    private let proxy: ProxyConfig?
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3"
    
    init(apiKey: String, proxy: ProxyConfig?) {
        self.apiKey = apiKey
        self.proxy = proxy
    }
    
    // MARK: AIServiceProtocol - Text (delegate to DeepSeekService for prompts)
    
    func generateOpening(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        let ds = DeepSeekService(apiKey: apiKey, proxy: proxy)
        return try await ds.generateOpening(worldTemplate: worldTemplate, customSetting: customSetting, characters: characters, style: style)
    }
    
    func continueStory(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        let ds = DeepSeekService(apiKey: apiKey, proxy: proxy)
        return try await ds.continueStory(currentNode: currentNode, choice: choice, storyHistory: storyHistory, style: style)
    }
    
    func generateTitle(for opening: String) async throws -> String {
        let ds = DeepSeekService(apiKey: apiKey, proxy: proxy)
        return try await ds.generateTitle(for: opening)
    }
    
    func moderateContent(_ text: String) async throws -> ContentModerationResult {
        return ContentModerator.moderateLocally(text)
    }
    
    func generateCharacterDetails(name: String, personality: String) async throws -> CharacterDetails {
        let ds = DeepSeekService(apiKey: apiKey, proxy: proxy)
        return try await ds.generateCharacterDetails(name: name, personality: personality)
    }
    
    // MARK: Image Generation
    
    func generateImage(description: String) async throws -> URL {
        guard !apiKey.contains("YOUR_") && !apiKey.isEmpty else {
            throw AIError.apiKeyMissing
        }
        
        let endpointID = Secrets.value(for: "ARK_IMAGE_ENDPOINT") ?? ""
        let endpoint = endpointID.isEmpty || endpointID.contains("YOUR_") ? "doubao-image-2-0" : endpointID
        
        let payload: [String: Any] = [
            "model": endpoint,
            "prompt": "\(description), 书籍插画风格, 电影级光影, 高清, 无文字水印",
            "n": 1,
            "size": "1024x1024"
        ]
        
        let url = URL(string: "\(baseURL)/images/generations")!
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let sessionConfig = URLSessionConfiguration.default
        if let proxy = proxy { proxy.configureSession(sessionConfig) }
        let session = URLSession(configuration: sessionConfig)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60
        
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw AIError.networkError(NSError(domain: body, code: statusCode))
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = json["data"] as? [[String: Any]],
              let first = dataList.first else {
            throw AIError.invalidResponse
        }
        
        // URL return
        if let imageURL = first["url"] as? String, let urlObj = URL(string: imageURL) {
            return urlObj
        }
        // Base64 return
        if let base64 = first["b64_json"] as? String, let imageData = Data(base64Encoded: base64) {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ark_\(UUID().uuidString).png")
            try imageData.write(to: fileURL)
            return fileURL
        }
        
        throw AIError.invalidResponse
    }

    // MARK: Streaming fallback

    func generateOpeningStreaming(
        worldTemplate: WorldTemplate, customSetting: String?,
        characters: [Character], style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                do {
                    let r = try await generateOpening(worldTemplate: worldTemplate,
                        customSetting: customSetting, characters: characters, style: style)
                    cont.yield(r.content); cont.finish()
                } catch { cont.finish(throwing: error) }
            }
        }
    }

    func continueStoryStreaming(
        currentNode: StoryNode, choice: StoryChoice?,
        storyHistory: [StoryNode], style: StoryStyle
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                do {
                    let r = try await continueStory(currentNode: currentNode,
                        choice: choice, storyHistory: storyHistory, style: style)
                    cont.yield(r.content); cont.finish()
                } catch { cont.finish(throwing: error) }
            }
        }
    }
}
@MainActor
final class QwenService {
    
    static let shared = QwenService()
    
    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1"
    
    init() {
        self.apiKey = Secrets.value(for: "QWEN_API_KEY") ?? ""
    }
    
    func generateImage(description: String) async throws -> URL {
        guard !apiKey.contains("YOUR_") && !apiKey.isEmpty else {
            throw AIError.apiKeyMissing
        }
        
        let payload: [String: Any] = [
            "model": "wanx-v1",
            "input": ["prompt": "\(description), 插画风格, 4K, 无水印"],
            "parameters": ["size": "1024*1024", "n": 1]
        ]
        
        let url = URL(string: "\(baseURL)/services/aigc/text2image/image-synthesis")!
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.httpBody = jsonData
        request.timeoutInterval = 120
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw AIError.networkError(NSError(domain: body, code: statusCode))
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let taskId = output["task_id"] as? String else {
            throw AIError.invalidResponse
        }
        
        return try await pollQwenTask(taskId: taskId)
    }
    
    private func pollQwenTask(taskId: String) async throws -> URL {
        let checkURL = URL(string: "https://dashscope.aliyuncs.com/api/v1/tasks/\(taskId)")!
        
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            var request = URLRequest(url: checkURL)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let output = json["output"] as? [String: Any],
               let results = output["results"] as? [[String: Any]],
               let first = results.first,
               let urlStr = first["url"] as? String,
               let url = URL(string: urlStr) {
                return url
            }
        }
        
        throw AIError.timeout
    }
}
