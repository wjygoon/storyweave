import SwiftUI

// MARK: - Primary Button
/// Rounded pill-style CTA with animated loading state and haptic feedback.

struct PrimaryButton: View {
    let title: String
    let icon: String?
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var size: ButtonSize = .regular
    var tint: PrimaryTint = .primary
    let action: () -> Void

    enum ButtonSize { case compact, regular, large }
    enum PrimaryTint { case primary, gold, gray, custom(AnyShapeStyle) }

    init(_ title: String,
         icon: String? = nil,
         size: ButtonSize = .regular,
         tint: PrimaryTint = .primary,
         isLoading: Bool = false,
         isDisabled: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.size = size
        self.tint = tint
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        let height: CGFloat = size == .compact ? 40 : size == .large ? 56 : 50
        let radius: CGFloat = height / 2

        Button {
            if !isLoading && !isDisabled { HapticManager.selection(); action() }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 18, weight: .semibold)) }
                    Text(title).font(Typography.button())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.fillStyle)
                    .shadow(color: tint.shadowColor, radius: 14, x: 0, y: 6)
            )
            .scaleEffect(isLoading ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.45 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    var isLoading: Bool = false
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            if !isLoading { HapticManager.selection(); action() }
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .medium)) }
                Text(title).font(Typography.button(15))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(ColorPalette.primary)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(ColorPalette.primary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Tertiary / Chip Button

struct ChipButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    var isPremium: Bool = false
    let action: () -> Void

    var body: some View {
        Button { HapticManager.selection(); action() } label: {
            HStack(spacing: 6) {
                if let icon { Text(icon) }
                Text(title).font(Typography.caption(14))
                if isPremium { Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(ColorPalette.gold) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? ColorPalette.primary : ColorPalette.card)
                    .overlay(Capsule().stroke(isSelected ? ColorPalette.primary : ColorPalette.hairline))
            )
            .foregroundStyle(isSelected ? .white : ColorPalette.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Choice Button (Reading page)

struct ChoiceButton: View {
    let choice: StoryChoice
    let isSelected: Bool
    let isLoading: Bool
    var surfaceColor: Color = ColorPalette.card
    var primaryTextColor: Color = ColorPalette.textPrimary
    var secondaryTextColor: Color = ColorPalette.textSecondary
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            if !isLoading { HapticManager.selection(); action() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ColorPalette.primary.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorPalette.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.text)
                        .font(Typography.body(16))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(3)

                    if let hint = choice.previewHint {
                        Text(hint)
                            .font(Typography.footnote(12))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(surfaceColor)
                    .shadow(color: .black.opacity(pressed ? 0.08 : 0.04),
                            radius: pressed ? 12 : 6, x: 0, y: pressed ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(isSelected ? ColorPalette.primary : ColorPalette.hairline, lineWidth: isSelected ? 1.5 : 0.5)
            )
            .scaleEffect(pressed ? 0.985 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pressed)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false })
    }
}


extension PrimaryButton.PrimaryTint {
    var fillStyle: AnyShapeStyle {
        switch self {
        case .primary: return AnyShapeStyle(ColorPalette.brandGradient)
        case .gold: return AnyShapeStyle(ColorPalette.goldGradient)
        case .gray: return AnyShapeStyle(Color.black.opacity(0.3))
        case .custom(let s): return s
        }
    }
    var shadowColor: Color {
        switch self {
        case .primary: return ColorPalette.primary.opacity(0.4)
        case .gold: return ColorPalette.gold.opacity(0.5)
        case .gray: return .black.opacity(0.15)
        case .custom: return .black.opacity(0.25)
        }
    }
}
