import Foundation

// MARK: - Seedream Image Service (火山方舟 · doubao-seedream-5-0)
/// 火山引擎方舟平台豆包文生图模型
/// 文档: https://www.volcengine.com/docs/82379/1397008
/// 成本: 0.22 元/张（标准分辨率）

final class SeedreamService {

    static let shared = SeedreamService()

    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3"
    private let model = "doubao-seedream-5-0"

    private var apiKey: String {
        // 优先用专用 seedream 密钥，fallback 到 ARK_API_KEY
        return Secrets.value(for: "SEEDREAM_API_KEY")
            ?? Secrets.value(for: "ARK_API_KEY")
            ?? ""
    }

    // MARK: Public

    /// 生成场景图像，返回可直接展示的 Data（JPEG/PNG）
    func generateSceneImage(
        description: String,
        style: String = "cinematic",
        resolution: String = "1024x1024"
    ) async throws -> Data {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_") else {
            throw AIError.apiKeyMissing
        }

        let prompt = buildImagePrompt(description: description, style: style)

        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "size": resolution,
            "n": 1
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: URL(string: "\(baseURL)/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.networkError(NSError(domain: body, code: code))
        }

        // Ark 方舟返回的是 data:image/png;base64 格式
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["data"] as? [[String: Any]],
              let first = images.first else {
            throw AIError.invalidResponse
        }

        // 优先 url，其次 b64_json
        if let urlStr = first["url"] as? String,
           let imageURL = URL(string: urlStr) {
            let (imgData, _) = try await URLSession.shared.data(from: imageURL)
            return imgData
        }

        if let b64 = first["b64_json"] as? String,
           let imgData = Data(base64Encoded: b64) {
            return imgData
        }

        throw AIError.invalidResponse
    }

    // MARK: Private

    private func buildImagePrompt(description: String, style: String) -> String {
        """
        \(description). Style: \(style) illustration for a story book, dramatic lighting, cinematic composition, detailed, high quality. No text, no watermarks, no logos. Safe for 12+ audience.
        """
    }
}
