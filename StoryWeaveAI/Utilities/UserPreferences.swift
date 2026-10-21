import Foundation

// MARK: - User Preferences
/// 用户偏好设置，使用 UserDefaults 持久化

final class UserPreferences: ObservableObject {
    
    static let shared = UserPreferences()
    
    // MARK: Published Properties
    
    @Published var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: Keys.appTheme) }
    }
    
    @Published var readingMode: ReadingMode {
        didSet { UserDefaults.standard.set(readingMode.rawValue, forKey: Keys.readingMode) }
    }
    
    @Published var readingFontSize: ReadingFontSize {
        didSet { UserDefaults.standard.set(readingFontSize.rawValue, forKey: Keys.readingFontSize) }
    }
    
    @Published var enableTypewriterEffect: Bool {
        didSet { UserDefaults.standard.set(enableTypewriterEffect, forKey: Keys.typewriter) }
    }
    
    @Published var enableAutoSave: Bool {
        didSet { UserDefaults.standard.set(enableAutoSave, forKey: Keys.autoSave) }
    }
    
    @Published var enableCloudSync: Bool {
        didSet { UserDefaults.standard.set(enableCloudSync, forKey: Keys.cloudSync) }
    }
    
    @Published var enableTeenMode: Bool {
        didSet { UserDefaults.standard.set(enableTeenMode, forKey: Keys.teenMode) }
    }
    
    @Published var teenModeDailyLimitMinutes: Int {
        didSet { UserDefaults.standard.set(teenModeDailyLimitMinutes, forKey: Keys.teenLimit) }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: Keys.haptic) }
    }
    
    @Published var lastDailyCreationReset: Date {
        didSet { UserDefaults.standard.set(lastDailyCreationReset, forKey: Keys.lastReset) }
    }
    
    @Published var todayCreationCount: Int {
        didSet { UserDefaults.standard.set(todayCreationCount, forKey: Keys.todayCount) }
    }
    
    // MARK: Init with Defaults
    
    private init() {
        let defaults = UserDefaults.standard
        
        // App Theme
        let themeRaw = defaults.string(forKey: Keys.appTheme) ?? AppTheme.system.rawValue
        appTheme = AppTheme(rawValue: themeRaw) ?? .system
        
        // Reading Mode
        let readingRaw = defaults.string(forKey: Keys.readingMode) ?? ReadingMode.paper.rawValue
        readingMode = ReadingMode(rawValue: readingRaw) ?? .paper
        
        // Font Size
        let fontSizeRaw = defaults.object(forKey: Keys.readingFontSize) as? CGFloat ?? ReadingFontSize.medium.rawValue
        readingFontSize = ReadingFontSize(rawValue: fontSizeRaw) ?? .medium
        
        // Switches
        enableTypewriterEffect = defaults.object(forKey: Keys.typewriter) as? Bool ?? true
        enableAutoSave = defaults.object(forKey: Keys.autoSave) as? Bool ?? true
        enableCloudSync = defaults.object(forKey: Keys.cloudSync) as? Bool ?? true
        enableTeenMode = defaults.object(forKey: Keys.teenMode) as? Bool ?? false
        hapticFeedbackEnabled = defaults.object(forKey: Keys.haptic) as? Bool ?? true
        
        // Teen Mode Limit
        teenModeDailyLimitMinutes = defaults.object(forKey: Keys.teenLimit) as? Int ?? 60
        
        // Daily Creation Tracking
        lastDailyCreationReset = defaults.object(forKey: Keys.lastReset) as? Date ?? Date()
        todayCreationCount = defaults.object(forKey: Keys.todayCount) as? Int ?? 0
        
        // Reset daily count if needed
        resetDailyCountIfNeeded()
    }
    
    // MARK: Daily Reset
    
    func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastDailyCreationReset) {
            lastDailyCreationReset = Date()
            todayCreationCount = 0
        }
    }
    
    /// 返回是否还能创建新故事（免费版限制）
    func canCreateNewStory(isPremium: Bool) -> Bool {
        if isPremium { return true }
        resetDailyCountIfNeeded()
        return todayCreationCount < AppConfig.Limits.freeDailyCreations
    }
    
    /// 记录一次故事创建
    func recordCreation() {
        resetDailyCountIfNeeded()
        todayCreationCount += 1
    }
    
    // MARK: Keys
    
    private enum Keys {
        static let appTheme = "pref_app_theme"
        static let readingMode = "pref_reading_mode"
        static let readingFontSize = "pref_font_size"
        static let typewriter = "pref_typewriter"
        static let autoSave = "pref_auto_save"
        static let cloudSync = "pref_cloud_sync"
        static let teenMode = "pref_teen_mode"
        static let teenLimit = "pref_teen_limit_min"
        static let haptic = "pref_haptic"
        static let lastReset = "pref_last_daily_reset"
        static let todayCount = "pref_today_creation_count"
    }
}
