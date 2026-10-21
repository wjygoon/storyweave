import Foundation

// MARK: - AI Provider
/// 支持多个 AI 服务提供商，大陆用户默认走国内线路

enum AIProvider: String, CaseIterable, Identifiable {
    // 海外
    case gemini        // Google Gemini（文本）
    case openai_dalle  // OpenAI DALL-E（图像）
    case seedream     // 火山方舟 Seedream（图像）⭐ 国内最优
    
    // 国内直连（大陆用户推荐）
    case deepseek      // DeepSeek V3（文本）⭐ 国内最好
    case ark           // 火山引擎/豆包（文本+图像）⭐ 字节跳动
    case qwen          // 阿里通义千问（文本+图像）
    case minimax       // MiniMax（文本）
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openai_dalle: return "OpenAI DALL-E"
        case .deepseek: return "DeepSeek"
        case .ark: return "豆包 / 火山引擎"
        case .qwen: return "通义千问"
        case .minimax: return "MiniMax"
        case .seedream: return "Seedream（豆包文生图）"
        }
    }
    
    /// 主要用途
    var primaryUse: AIProviderUse {
        switch self {
        case .gemini, .deepseek, .ark, .qwen, .minimax: return .text
        case .openai_dalle, .seedream: return .image
        }
    }
    
    /// 是否需要代理才能访问
    var needsProxy: Bool {
        switch self {
        case .gemini, .openai_dalle: return true
        case .deepseek, .ark, .qwen, .minimax, .seedream: return false
        }
    }
    
    /// base URL
    var baseURL: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openai_dalle: return "https://api.openai.com/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .ark: return "https://ark.cn-beijing.volces.com/api/v3"
        case .qwen: return "https://dashscope.aliyuncs.com/api/v1"
        case .minimax: return "https://api.minimax.chat/v1"
        case .seedream: return "https://ark.cn-beijing.volces.com/api/v3"
        }
    }
    
    /// 推荐的默认 provider（根据地区）
    static func recommendedFor(region: Region) -> (text: AIProvider, image: AIProvider) {
        switch region {
        case .china: return (.deepseek, .ark)
        case .overseas: return (.gemini, .openai_dalle)
        case .auto: return (.deepseek, .ark)  // 默认国内优先
        }
    }
}

enum AIProviderUse {
    case text
    case image
    case both
}

enum Region: String, CaseIterable, Identifiable {
    case china
    case overseas
    case auto
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .china: return "中国大陆"
        case .overseas: return "海外 / 港澳台"
        case .auto: return "自动检测"
        }
    }
}
