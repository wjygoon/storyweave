import Foundation

// MARK: - Supabase Config
/// Supabase 配置管理和基础 HTTP 客户端
/// 注意：完整实现需引入 Supabase Swift SDK，当前为轻量级直接 HTTP 调用方案

enum SupabaseConfig {
    
    /// 获取 Supabase 实例配置
    static var configuration: (url: String, anonKey: String)? {
        let url = AppConfig.API.supabaseURL
        let key = AppConfig.API.supabaseAnonKey
        
        guard !url.contains("YOUR_"), !key.contains("YOUR_") else {
            return nil  // 未配置
        }
        return (url, key)
    }
}

// MARK: - Supabase API Client
/// 轻量级 Supabase REST API 客户端

final class SupabaseClient {
    
    static let shared = SupabaseClient()
    
    private(set) var authToken: String?
    
    private init() {}
    
    // MARK: Auth Token Management
    
    var isAuthenticated: Bool {
        return authToken != nil
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
        if let token = token {
            UserDefaults.standard.set(token, forKey: "supabase_auth_token")
        } else {
            UserDefaults.standard.removeObject(forKey: "supabase_auth_token")
        }
    }
    
    func restoreAuth() {
        authToken = UserDefaults.standard.string(forKey: "supabase_auth_token")
    }
    
    // MARK: Request Builder
    
    func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        guard let config = SupabaseConfig.configuration else {
            throw SupabaseError.notConfigured
        }
        
        let url = URL(string: "\(config.url)/rest/v1/\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("public, auth", forHTTPHeaderField: "Authorization")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return data
    }
    
    // MARK: - Data Sync Helpers
    
    /// 上传故事到云端
    func uploadStory(_ story: [String: Any]) async throws {
        _ = try await makeRequest(
            endpoint: "stories",
            method: "POST",
            body: story,
            requiresAuth: true
        )
    }
    
    /// 获取用户的所有云端故事
    func fetchUserStories(userId: String) async throws -> [[String: Any]] {
        let data = try await makeRequest(
            endpoint: "stories?user_id=eq.\(userId)&select=*",
            method: "GET",
            requiresAuth: true
        )
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }
    
    /// 删除云端故事
    func deleteStory(storyId: UUID) async throws {
        _ = try await makeRequest(
            endpoint: "stories?id=eq.\(storyId.uuidString)",
            method: "DELETE",
            requiresAuth: true
        )
    }
}

// MARK: - Supabase Errors

enum SupabaseError: LocalizedError {
    case notConfigured
    case networkError
    case apiError(statusCode: Int, message: String)
    case authFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 未配置，请在 Secrets.plist 中填写 SUPABASE_URL 和 SUPABASE_ANON_KEY"
        case .networkError:
            return "网络连接错误"
        case .apiError(let code, let msg):
            return "Supabase API 错误 (\(code)): \(msg)"
        case .authFailed:
            return "认证失败"
        case .unknown:
            return "发生未知错误"
        }
    }
}
