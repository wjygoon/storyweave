import Foundation

// MARK: - DALL-E Image Service
/// 使用 DALL-E 3 API 生成场景插图

final class DALLEService {
    
    static let shared = DALLEService()
    
    // MARK: Properties
    
    private let baseURL = "https://api.openai.com/v1"
    
    // MARK: Public API
    
    /// 生成场景图像
    func generateSceneImage(description: String, style: String = "cinematic") async throws -> URL {
        guard !AppConfig.API.dalleKey.contains("YOUR_") else {
            throw AIError.apiKeyMissing
        }
        
        let prompt = buildImagePrompt(description: description, style: style)
        
        let payload: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "quality": "standard"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.API.dalleKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.networkError(NSError(domain: errorBody, code: code))
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["data"] as? [[String: Any]],
              let urlString = images.first?["url"] as? String,
              let imageURL = URL(string: urlString) else {
            throw AIError.invalidResponse
        }
        
        return imageURL
    }
    
    /// 下载图像到本地缓存
    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw AIError.networkError(NSError(domain: "Image download failed", code: -1))
        }
        
        // 保存到缓存目录
        let cacheURL = try saveToCache(data: data, from: url)
        _ = cacheURL
        
        return data
    }
    
    // MARK: Private
    
    private func buildImagePrompt(description: String, style: String) -> String {
        return """
        \(description). Style: \(style) illustration for a story book, dramatic lighting, detailed, high quality, 4K. No text, no watermarks, no logos. Safe for 12+ audience.
        """
    }
    
    private func saveToCache(data: Data, from url: URL) throws -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileName = url.lastPathComponent.isEmpty ? UUID().uuidString + ".png" : url.lastPathComponent
        let fileURL = cacheDir.appendingPathComponent("StoryWeaveImages/\(fileName)")
        
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try data.write(to: fileURL)
        return fileURL
    }
}
