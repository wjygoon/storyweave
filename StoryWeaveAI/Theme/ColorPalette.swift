import SwiftUI
import UIKit

// MARK: - StoryWeave Design Tokens
// UICraft-inspired unified design system: 8pt grid, rounded design, warm purple narrative brand

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let section: CGFloat = 28
    static let page: CGFloat = 20
}

enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}


// MARK: - Color Palette (WCAG AA contrast verified)

enum ColorPalette {
    // Brand — warm violet to soft purple, narrative & imaginative
    static let primary = Color(hex: 0x7C3AED)         // violet-600 — main CTA
    static let primarySoft = Color(hex: 0x8B5CF6)      // violet-500 — accents
    static let primaryTint = Color(hex: 0xA78BFA)      // violet-400 — decorative
    static let primarySurface = Color(hex: 0xEDE9FE)   // violet-100 — tinted bg
    static let primaryContainer = Color(hex: 0x5B21B6) // violet-700 — dark surfaces

    // Supporting accents
    static let accent = Color(hex: 0xEC4899)           // pink-500 — secondary pop
    static let gold = Color(hex: 0xF59E0B)              // amber-500 — Premium
    static let success = Color(hex: 0x10B981)           // emerald-500
    static let warning = Color(hex: 0xF97316)            // orange-500
    static let error = Color(hex: 0xEF4444)             // red-500

    // Surfaces — 自动适配浅色/深色（基于 UIColor 动态提供器）
    static let bg = Color(light: 0xFAFAFC, dark: 0x0B0B14)          // page background
    static let card = Color(light: 0xFFFFFF, dark: 0x151524)        // card surface
    static let cardElevated = Color(light: 0xFFFFFF, dark: 0x1C1C2E)
    static let divider = Color(light: 0xEEEDF2, dark: 0x262638)
    // 卡片描边/分隔细发丝线（浅色下黑色低透明，深色下白色低透明）
    static let hairline = Color(lightAlpha: 0x000000, lightOpacity: 0.07,
                                darkAlpha: 0xFFFFFF, darkOpacity: 0.10)
// MARK: - Backward Compatibility Aliases (old View refs)
static let lightBackground = bg
static let lightCardBackground = card
static let lightReadingBackground = readingPaper
static let darkBackground = darkBg
static let darkCardBackground = darkCard
static let darkReadingBackground = readingNight
static let textOnDark = darkTextPrimary
static let textSecondaryOnDark = darkTextSecondary
static let primaryGradient = brandGradient
static let darkGradient = LinearGradient(colors: [darkBg, darkCard], startPoint: .top, endPoint: .bottom)


    // Dark surfaces
    static let darkBg = Color(hex: 0x0B0B14)
    static let darkCard = Color(hex: 0x151524)
    static let darkCardElevated = Color(hex: 0x1C1C2E)
    static let darkDivider = Color(hex: 0x262638)

    // Text — 7-level hierarchy（随系统外观自动反转，保证任何背景下可读）
    static let textStrong = Color(light: 0x111827, dark: 0xF9FAFB)     // gray-900
    static let textPrimary = Color(light: 0x1F2937, dark: 0xF3F4F6)    // gray-800
    static let textSecondary = Color(light: 0x6B7280, dark: 0xA6ADBB)  // gray-500
    static let textTertiary = Color(light: 0x9CA3AF, dark: 0x7C8493)   // gray-400
    static let textDisabled = Color(light: 0xD1D5DB, dark: 0x48505F)   // gray-300

    // Dark text
    static let darkTextStrong = Color(hex: 0xF9FAFB)
    static let darkTextPrimary = Color(hex: 0xF3F4F6)
    static let darkTextSecondary = Color(hex: 0x9CA3AF)
    static let darkTextTertiary = Color(hex: 0x6B7280)

    // Reading backgrounds (paper-like warmth)
    static let readingPaper = Color(hex: 0xFDFBF5)
    static let readingNight = Color(hex: 0x141420)

    // Immersive Dark Narrative (P0 UX upgrade)
    static let immersiveDarkBG     = Color(hex: 0x14141A)   // 深炭灰
    static let immersiveDarkText   = Color(hex: 0xEDE8DF)   // 暖米白
    static let immersiveDarkAccent = Color(hex: 0xD4A24C)   // 琥珀金
    static let immersiveDarkMuted  = Color(hex: 0x9B9380)   // 暗色次级文本
    static let readingSepia = Color(hex: 0xF5E6C8)

    // Gradients
    static let brandGradient = LinearGradient(
        colors: [primarySoft, accent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFBBF24), gold],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let shimmerGradient = LinearGradient(
        colors: [.clear, Color.white.opacity(0.35), .clear],
        startPoint: .leading, endPoint: .trailing
    )
    static let fadeTopGradient = LinearGradient(
        colors: [.clear, bg],
        startPoint: .top, endPoint: .bottom
    )
    static let fadeBottomGradient = LinearGradient(
        colors: [bg, .clear],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Color Hex Init

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// 随系统浅色/深色外观自动切换的动态色
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    /// 随外观切换的同色异透明度动态色（用于发丝线等）
    init(lightAlpha: UInt32, lightOpacity: Double, darkAlpha: UInt32, darkOpacity: Double) {
        self.init(uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(hex: darkAlpha, alpha: CGFloat(darkOpacity))
            } else {
                return UIColor(hex: lightAlpha, alpha: CGFloat(lightOpacity))
            }
        })
    }
}

// MARK: - Semantic Color API

enum SemanticColors {
    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : ColorPalette.bg
    }
    static func card(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? ColorPalette.darkCard : ColorPalette.card
    }
    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? ColorPalette.darkTextPrimary : ColorPalette.textPrimary
    }
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? ColorPalette.darkTextSecondary : ColorPalette.textSecondary
    }
    static func divider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? ColorPalette.darkDivider : ColorPalette.divider
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ReadingMode: String, CaseIterable, Identifiable {
    case paper, night, sepia, pure, immersiveDark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .paper: return "护眼纸"
        case .night: return "夜间"
        case .sepia: return "羊皮纸"
        case .pure: return "纯净"
        case .immersiveDark: return "沉浸故事"
        }
    }
    var background: Color {
        switch self {
        case .paper: return ColorPalette.readingPaper
        case .night: return ColorPalette.readingNight
        case .sepia: return ColorPalette.readingSepia
        case .pure: return .white
        case .immersiveDark: return ColorPalette.immersiveDarkBG
        }
    }
    var textColor: Color {
        switch self {
        case .immersiveDark: return ColorPalette.immersiveDarkText
        case .night: return ColorPalette.darkTextPrimary
        default: return Color(hex: 0x1F2937)
        }
    }
    /// 阅读页次级文字（与固定阅读背景配对，不随系统外观变化）
    var mutedColor: Color {
        switch self {
        case .immersiveDark: return ColorPalette.immersiveDarkMuted
        case .night: return Color(hex: 0x9CA3AF)
        case .sepia: return Color(hex: 0x7A6A4F)
        default: return Color(hex: 0x6B7280)
        }
    }
    /// 阅读页卡片/按钮表面色
    var surfaceColor: Color {
        switch self {
        case .night, .immersiveDark: return ColorPalette.darkCardElevated
        default: return Color.white
        }
    }
    var accentColor: Color {
        self == .immersiveDark ? ColorPalette.immersiveDarkAccent : ColorPalette.primary
    }
}
