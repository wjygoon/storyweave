import SwiftUI
import SwiftData
import UIKit

// MARK: - StoryWeave App Entry Point

@main
struct StoryWeaveApp: App {
    
    // MARK: State
    
    @StateObject private var userPrefs = UserPreferences.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var storeKitManager = StoreKitManager.shared
    @ObservedObject private var compliance = ComplianceManager.shared
    @State private var showDemoStory = false
    
    // MARK: Body
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(UserPreferences.shared.appTheme.colorScheme)
                .environmentObject(userPrefs)
                .environmentObject(authManager)
                .environmentObject(storeKitManager)
                .tint(ColorPalette.primary)
                .environmentObject(compliance)
                .complianceGate(isPresented: !compliance.isCompliant, state: compliance.state)
                .fullScreenCover(isPresented: $showDemoStory) {
                    DemoStoryView { showDemoStory = false }
                }
                .onAppear {
                    if compliance.isCompliant && !UserDefaults.standard.bool(forKey: "onboarding.demo_seen") {
                        showDemoStory = true
                    }
                }
                .onChange(of: compliance.isCompliant) { old, isCompliant in
                    if isCompliant && !UserDefaults.standard.bool(forKey: "onboarding.demo_seen") {
                        showDemoStory = true
                    }
                }
                .onAppear { applyWindowAppearance(userPrefs.appTheme) }
                .onChange(of: userPrefs.appTheme) { _, theme in
                    applyWindowAppearance(theme)
                }
        }
        .modelContainer(for: [Story.self, StoryNode.self, Character.self], inMemory: false)
    }

    /// 强制整个 Window（含状态栏）跟随所选外观；preferredColorScheme 单独使用时状态栏可能不更新
    private func applyWindowAppearance(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

// MARK: - Main Tab View
/// 主Tab导航，包含：首页 / 创建故事 / 角色 / 设置

struct MainTabView: View {
    
    @ObservedObject private var storeKit = StoreKitManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("发现", systemImage: "sparkles")
            }
            .tag(0)
            
            NavigationStack {
                StoryCreationEntryView()
            }
            .tabItem {
                Label("创作", systemImage: "plus.circle.fill")
            }
            .tag(1)
            
            NavigationStack {
                CharacterListView()
            }
            .tabItem {
                Label("角色", systemImage: "person.2")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(ColorPalette.primary)
        .overlay(alignment: .bottom) {
            // 青少年模式提示
            if UserPreferences.shared.enableTeenMode {
                teenModeBadge
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // 每次点击 Tab 都滚动到顶部（用户偏好）
            if oldValue == newValue {
                // 触发同tab滚动到顶部通知
                NotificationCenter.default.post(name: .tabTappedSameTab, object: newValue)
            }
            HapticManager.selection()
        }
    }
    
    private var teenModeBadge: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
            Text("青少年模式")
        }
        .font(Typography.footnote(11))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(ColorPalette.gold)
        )
        .offset(y: -48)
    }
}

// MARK: - Tab Notification

extension Notification.Name {
    static let tabTappedSameTab = Notification.Name("tabTappedSameTab")
}


// MARK: - Compliance Gate Extension

extension View {
    @ViewBuilder
    func complianceGate(isPresented: Bool, state: ComplianceGateState) -> some View {
        self
            .disabled(isPresented)
            .blur(radius: isPresented ? 2 : 0)
            .overlay {
                if isPresented {
                    WelcomeConsentView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(true)
                        .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPresented)
    }
}
