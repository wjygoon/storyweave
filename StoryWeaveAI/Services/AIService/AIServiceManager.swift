import Foundation

// MARK: - AI Service Manager
/// 统一调度 AI 服务，根据地区/用户配置自动选择最优 provider

@MainActor
final class AIServiceManager: ObservableObject {
    
    static let shared = AIServiceManager()
    
    // MARK: Published
    
    @Published var textProvider: AIProvider = .deepseek
    @Published var imageProvider: AIProvider = .seedream
    @Published var region: Region = .auto
    @Published var proxyConfig: ProxyConfig?
    @Published var isConfigured: Bool = false
    
    // MARK: Properties
    
    private var lazyDeepSeek: DeepSeekService?
    private var lazyArk: ArkService?
    private var geminiService = GeminiService.shared
    private var dalleService = DALLEService.shared
    
    // MARK: Init
    
    private init() {
        loadConfig()
    }
    
    private func loadConfig() {
        let prefs = UserDefaults.standard
        
        if let textRaw = prefs.string(forKey: "ai_text_provider"),
           let provider = AIProvider(rawValue: textRaw) {
            textProvider = provider
        }
        
        if let imageRaw = prefs.string(forKey: "ai_image_provider"),
           let provider = AIProvider(rawValue: imageRaw) {
            imageProvider = provider
        }
        
        if let regionRaw = prefs.string(forKey: "ai_region"),
           let r = Region(rawValue: regionRaw) {
            region = r
        } else {
            region = .auto
            autoDetectRegion()
        }
        
        setupProxy()
        checkConfiguration()
    }
    
    // MARK: Region Auto-Detect
    
    private func autoDetectRegion() {
        // 利用 NSLocale 粗略判断
        let locale = Locale.current
        let code = locale.region?.identifier ?? ""
        if code == "CN" || code == "cn" {
            region = .china
            textProvider = .deepseek
            imageProvider = .seedream
        } else {
            region = .overseas
            textProvider = .gemini
            imageProvider = .openai_dalle
        }
        saveConfig()
    }
    
    // MARK: Proxy
    
    private func setupProxy() {
        // 从 UserDefaults 读取代理配置
        if let host = UserDefaults.standard.string(forKey: "proxy_host"),
           let port = UserDefaults.standard.object(forKey: "proxy_port") as? Int {
            proxyConfig = ProxyConfig(host: host, port: port)
        }
    }
    
    // MARK: Config Check
    
    private func checkConfiguration() {
        // 检查当前选择的 provider 是否有 API Key
        let hasTextKey = hasAPIKey(for: textProvider)
        let hasImageKey = hasAPIKey(for: imageProvider)
        isConfigured = hasTextKey && hasImageKey
    }
    
    private func hasAPIKey(for provider: AIProvider) -> Bool {
        let key: String?
        switch provider {
        case .deepseek: key = Secrets.value(for: "DEEPSEEK_API_KEY")
        case .ark: key = Secrets.value(for: "ARK_API_KEY")
        case .qwen: key = Secrets.value(for: "QWEN_API_KEY")
        case .seedream: key = Secrets.value(for: "SEEDREAM_API_KEY") ?? Secrets.value(for: "ARK_API_KEY")
        case .minimax: key = Secrets.value(for: "MINIMAX_API_KEY")
        case .gemini: key = AppConfig.API.geminiKey
        case .openai_dalle: key = AppConfig.API.dalleKey
        }
        guard let key = key, !key.contains("YOUR_"), !key.isEmpty else { return false }
        return true
    }
    
    // MARK: Text Generation
    
    func generateOpening(
        worldTemplate: WorldTemplate,
        customSetting: String?,
        characters: [Character],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        let service = textService()
        return try await service.generateOpening(
            worldTemplate: worldTemplate,
            customSetting: customSetting,
            characters: characters,
            style: style
        )
    }
    
    func continueStory(
        currentNode: StoryNode,
        choice: StoryChoice?,
        storyHistory: [StoryNode],
        style: StoryStyle
    ) async throws -> StoryGenerationResult {
        let service = textService()
        return try await service.continueStory(
            currentNode: currentNode,
            choice: choice,
            storyHistory: storyHistory,
            style: style
        )
    }
    
    func generateTitle(for opening: String) async throws -> String {
        let service = textService()
        return try await service.generateTitle(for: opening)
    }
    
    // MARK: Image Generation
    
    func generateSceneImageData(description: String, style: String = "cinematic") async throws -> Data {
        switch imageProvider {
        case .seedream:
            return try await SeedreamService.shared.generateSceneImage(description: description)
        case .ark:
            let ark = try getArk()
            let url = try await ark.generateImage(description: description)
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        case .qwen:
            let qwen = QwenService.shared
            let url = try await qwen.generateImage(description: description)
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        case .openai_dalle:
            let url = try await dalleService.generateSceneImage(description: description, style: style)
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        default:
            let url = try await dalleService.generateSceneImage(description: description, style: style)
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    }
    
    // MARK: Text Routing
    
    private func textService() -> AIServiceProtocol {
        switch textProvider {
        case .deepseek:
            let ds = try? getDeepSeek()
            return ds ?? geminiService  // fallback
        case .ark:
            let ark = try? getArk()
            return ark ?? geminiService
        case .gemini:
            return geminiService
        case .qwen, .minimax, .seedream:
            return DeepSeekService.shared  // 暂时 fallback
        case .openai_dalle:
            return geminiService
        }
    }
    
    // MARK: Lazy Services
    
    private func getDeepSeek() throws -> DeepSeekService {
        if let existing = lazyDeepSeek { return existing }
        let key = Secrets.value(for: "DEEPSEEK_API_KEY") ?? ""
        guard !key.contains("YOUR_") && !key.isEmpty else {
            throw AIError.apiKeyMissing
        }
        let svc = DeepSeekService(apiKey: key, proxy: proxyConfig)
        lazyDeepSeek = svc
        return svc
    }
    
    private func getArk() throws -> ArkService {
        if let existing = lazyArk { return existing }
        let key = Secrets.value(for: "ARK_API_KEY") ?? ""
        guard !key.contains("YOUR_") && !key.isEmpty else {
            throw AIError.apiKeyMissing
        }
        let svc = ArkService(apiKey: key, proxy: proxyConfig)
        lazyArk = svc
        return svc
    }
    
    // MARK: Public
    
    func setProviders(text: AIProvider, image: AIProvider) {
        textProvider = text
        imageProvider = image
        UserDefaults.standard.set(text.rawValue, forKey: "ai_text_provider")
        UserDefaults.standard.set(image.rawValue, forKey: "ai_image_provider")
        checkConfiguration()
    }
    
    func setRegion(_ region: Region) {
        self.region = region
        UserDefaults.standard.set(region.rawValue, forKey: "ai_region")
        
        if region == .china {
            textProvider = .deepseek
            imageProvider = .ark
        } else if region == .overseas {
            textProvider = .gemini
            imageProvider = .openai_dalle
        }
        checkConfiguration()
    }
    
    func setProxy(host: String, port: Int) {
        proxyConfig = ProxyConfig(host: host, port: port)
        UserDefaults.standard.set(host, forKey: "proxy_host")
        UserDefaults.standard.set(port, forKey: "proxy_port")
        lazyDeepSeek = nil  // 重建连接
        lazyArk = nil
    }
    
    func clearProxy() {
        proxyConfig = nil
        UserDefaults.standard.removeObject(forKey: "proxy_host")
        UserDefaults.standard.removeObject(forKey: "proxy_port")
        lazyDeepSeek = nil
        lazyArk = nil
    }
    
    private func saveConfig() {
        UserDefaults.standard.set(textProvider.rawValue, forKey: "ai_text_provider")
        UserDefaults.standard.set(imageProvider.rawValue, forKey: "ai_image_provider")
        UserDefaults.standard.set(region.rawValue, forKey: "ai_region")
    }
}

// MARK: - Proxy Config

struct ProxyConfig {
    let host: String
    let port: Int
    
    var url: URL? {
        URL(string: "http://\(host):\(port)")
    }
    
    /// 应用到 URLSession
    func configureSession(_ sessionConfig: URLSessionConfiguration) {
        sessionConfig.connectionProxyDictionary = [
            "HTTPEnable": true, "HTTPProxy": host, "HTTPPort": port,
            "HTTPSEnable": true, "HTTPSProxy": host, "HTTPSPort": port
        ]
    }
}
