import SwiftUI

// MARK: - Typography
// Clear 6-level hierarchy. Uses .rounded design everywhere for warm, narrative feel.
// Supports Dynamic Type where appropriate.

enum Typography {

    // MARK: Headings

    static func display(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func largeTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func subtitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func heading(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // MARK: Body

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    // MARK: Reading (serif for narrative immersion)

    static func reading(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    // MARK: UI text

    static func button(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func caption(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func footnote(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func micro(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

enum ReadingFontSize: CGFloat, CaseIterable, Identifiable {
    case small = 15, medium = 18, large = 21, extraLarge = 24
    var id: CGFloat { rawValue }
    var displayName: String {
        [.small: "小", .medium: "标准", .large: "大", .extraLarge: "特大"][self]!
    }
}
