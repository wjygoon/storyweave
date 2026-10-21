import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Auth Manager
/// 统一管理 Apple 登录 + Supabase 认证

@MainActor
final class AuthManager: ObservableObject {
    
    static let shared = AuthManager()
    
    // MARK: Published
    
    @Published var currentUser: UserProfile?
    @Published var isAuthenticating: Bool = false
    @Published var authError: AuthError?
    
    // MARK: State
    
    private var appleSignInDelegates: [AppleSignInDelegate] = []
    
    // MARK: Init
    
    private init() {
        // 恢复会话
        restoreSession()
    }
    
    // MARK: Public API
    
    /// 启动苹果登录
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let delegate = AppleSignInDelegate()
        delegate.onCompletion = { [weak self] result in
            Task { await self?.handleAppleSignInResult(result) }
        }
        
        appleSignInDelegates.append(delegate)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }
    
    /// 登出
    func signOut() {
        currentUser = nil
        SupabaseClient.shared.setAuthToken(nil)
        UserDefaults.standard.removeObject(forKey: "user_profile")
        appleSignInDelegates.removeAll()
    }
    
    /// 删除账号：云端硬删 + 本地全清 + 回到未登录态
    /// 网络失败时仍执行本地删除，并返回 isCloudDeleted=false 供 UI 提示
    func deleteAccount() async throws {
        let cloudDeleted = try await deleteCloudAccount()
        clearAllLocalData()
        signOut()
        if !cloudDeleted {
            authError = .supabaseSyncFailed(NSError(domain: "云端账号可能未删除，请稍后重试或联系 support@storyweave.ai", code: -1))
        }
    }

    // MARK: Account Deletion Helpers

    private func deleteCloudAccount() async throws -> Bool {
        guard SupabaseClient.shared.authToken != nil,
              SupabaseConfig.configuration != nil else { return false }
        do {
            // Supabase DELETE /auth/v1/user（Bearer 会话 token）
            _ = try await SupabaseClient.shared.makeRequest(
                endpoint: "auth/v1/user",
                method: "DELETE",
                requiresAuth: true
            )
            return true
        } catch {
            print("[Delete] Supabase delete failed: \(error.localizedDescription)")
            return false
        }
    }

    private func clearAllLocalData() {
        let defaults = UserDefaults.standard
        let keys = ["user_profile", "apple_full_name", "apple_email",
                    "q_remaining_story", "q_remaining_image", "q_rewarded",
                    "q_last_reset", "q_checked_in_today", "q_last_checkin",
                    "q_paywall_dismiss", "q_onboard_claimed", "q_trial_end",
                    "paywall.stories_completed", "paywall.rewind_prompt_shown",
                    "compliance.ai_consent", "compliance.age_confirmed",
                    "compliance.eula_accepted", "compliance.eula_version",
                    "teen_mode_promoted"]
        keys.forEach { defaults.removeObject(forKey: $0) }
        // SwiftData 清空
        try? DataManager.shared.clearAll()
        // Keychain（如有）
        let _ = KeychainHelper.delete(key: "supabase_token")
    }
    
    // MARK: Internal
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = .credentialFailed
                return
            }
            
            let userId = credential.user
            let fullName = credential.fullName
            let email = credential.email
            
            // 保存完整姓名（可能只在首次登录返回）
            if let fullName = fullName {
                let name = [fullName.givenName, fullName.familyName].compactMap { $0 }.joined()
                UserDefaults.standard.set(name, forKey: "apple_full_name")
            }
            
            if let email = email {
                UserDefaults.standard.set(email, forKey: "apple_email")
            }
            
            // 构建用户档案
            let profile = UserProfile(
                id: userId,
                name: UserDefaults.standard.string(forKey: "apple_full_name") ?? "StoryWeave 用户",
                email: UserDefaults.standard.string(forKey: "apple_email"),
                avatarURL: nil,
                isNewUser: false,
                createdAt: Date()
            )
            
            // 保存到本地
            currentUser = profile
            saveProfile(profile)
            
            // 尝试同步到 Supabase（如已配置）
            if SupabaseConfig.configuration != nil {
                await syncToSupabase(user: profile)
            }
            
            HapticManager.success()
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // 用户取消，不是错误
                return
            }
            self.authError = .signInFailed(error)
        }
    }
    
    private func syncToSupabase(user: UserProfile) async {
        // 将 Apple 的 identityToken 发送到 Supabase 进行认证
        // 完整实现需要解析 token 并调用 supabase.auth.signInWithIdToken
        // 这里简化为直接注册用户信息
        do {
            _ = try await SupabaseClient.shared.makeRequest(
                endpoint: "users",
                method: "POST",
                body: [
                    "id": user.id,
                    "name": user.name,
                    "email": user.email ?? "",
                    "created_at": ISO8601DateFormatter().string(from: user.createdAt)
                ],
                requiresAuth: false
            )
        } catch {
            // 同步失败不阻塞本地登录
            print("Supabase sync failed: \(error.localizedDescription)")
        }
    }
    
    private func restoreSession() {
        // 恢复 Supabase token
        SupabaseClient.shared.restoreAuth()
        
        // 恢复用户档案
        if let data = UserDefaults.standard.data(forKey: "user_profile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            currentUser = profile
        }
    }
    
    private func saveProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "user_profile")
        }
    }
}

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    let id: String
    var name: String
    var email: String?
    var avatarURL: String?
    var isNewUser: Bool
    var createdAt: Date
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case credentialFailed
    case signInFailed(Error)
    case supabaseSyncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .credentialFailed:
            return "无法获取 Apple 凭据"
        case .signInFailed(let error):
            return "登录失败：\(error.localizedDescription)"
        case .supabaseSyncFailed(let error):
            return "云端同步失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - Apple Sign In Delegate Helper
/// 帮助实现 ASAuthorizationControllerDelegate 和 presentation context

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
    
    @MainActor func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 获取当前活跃窗口
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}


// MARK: - Keychain Helper (zero-dep fallback)

enum KeychainHelper {
    private static let fallback = UserDefaults(suiteName: "group.storyweave.keychain")
    @discardableResult static func save(key: String, value: String) -> Bool { fallback?.set(value, forKey: key); return true }
    static func load(key: String) -> String? { fallback?.string(forKey: key) }
    @discardableResult static func delete(key: String) -> Bool { fallback?.removeObject(forKey: key); return true }
}
