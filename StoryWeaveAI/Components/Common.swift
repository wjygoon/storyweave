import SwiftUI

// MARK: - Shimmer (skeleton loading)

struct ShimmeringView: View {
    let baseColor: Color
    let highlightColor: Color
    @State private var phase: CGFloat = -0.6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width + 200
            baseColor.overlay(
                LinearGradient(colors: [
                    highlightColor.opacity(0.0),
                    highlightColor.opacity(0.6),
                    highlightColor.opacity(0.0)
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: 160)
                .offset(x: phase * width)
                .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 1.2 }
        }
        .clipped()
    }
}

extension View {
    func shimmering() -> some View {
        self
            .hidden()
            .overlay(
                ShimmeringView(baseColor: ColorPalette.divider, highlightColor: Color.white)
                    .mask(self)
            )
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(ColorPalette.primary.opacity(0.08))
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(ColorPalette.primary.opacity(0.15))
                    .frame(width: 68, height: 68)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(ColorPalette.primary)
            }

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.subtitle())
                    .foregroundStyle(ColorPalette.textPrimary)
                Text(message)
                    .font(Typography.body(14))
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xl)
            }

            if let actionTitle, let action {
                PrimaryButton(actionTitle, icon: "plus", size: .regular, action: action)
                    .padding(.horizontal, Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    init(message: String = "AI 正在构思...") { self.message = message }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(ColorPalette.primary.opacity(0.25), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(ColorPalette.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: UUID())
                }
                .frame(width: 52, height: 52)

                Text(message)
                    .font(Typography.caption(13))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(ColorPalette.darkCard.opacity(0.92))
            )
            .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
        }
    }
}

// MARK: - Card Container

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(ColorPalette.card)
                    .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title; self.actionTitle = actionTitle; self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.heading())
                .foregroundStyle(ColorPalette.textStrong)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.footnote(13))
                        .foregroundStyle(ColorPalette.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.page)
    }
}
