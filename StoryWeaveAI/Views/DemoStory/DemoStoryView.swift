import SwiftUI

// MARK: - Demo Onboarding Story
// 首启完成合规门控后直接进入，3 节点无 AI 调用，结束引导至创建页

enum DemoStory {
    static let title = "第一缕晨光"
    static let worldSetting = "一座被薄雾环绕的小镇，传说凌晨四点的钟楼会敲出只有旅人能听见的旋律。"

    struct Node {
        let content: String
        let choices: [(String, String)]
    }

    static let nodes: [Node] = [
        Node(content: "凌晨三点四十七分。你被窗外一阵不属于这个小镇的低沉钟声唤醒。窗外的薄雾在路灯下翻涌，像有什么东西正从山那边走来。枕边留着一张你完全不记得收到的纸条——墨迹还未干。",
             choices: [
                ("接过那张皱巴巴的纸条", "先看清上面写了什么"),
                ("推开窗户望向钟楼", "钟声才是答案"),
                ("把纸条塞进口袋重新躺下", "假装什么都没发生"),
                ("点上一盏灯坐到天亮", "等待是最诚实的选择")
             ]),
        Node(content: "纸条上用铅笔歪歪扭扭写着一行字：「第四下钟声响起时，别让它照到你。」你意识到这不是梦——镇口的杂货铺上周失窃的老老板也留下过同样的字。",
             choices: [
                ("披上外套冲向镇口杂货铺", "纸条的主人也许还在那里"),
                ("翻出爷爷留下的旧怀表", "先搞清楚现在到底几点"),
                ("把纸条烧在壁炉里", "有些秘密不该被读到"),
                ("拨通镇上警察的电话", "该有人管管了")
             ]),
        Node(content: "你推开门。薄雾退散了一寸。钟楼的方向，一个模糊的黑影正沿着石板路朝这边走。它没有脚步声。晨钟，在它经过的地方，提前敲响了第四下。",
             choices: [])
    ]
}

// MARK: - Demo Story Viewer

struct DemoStoryView: View {
    let onFinish: () -> Void
    @State private var nodeIndex = 0
    @State private var displayed = ""
    @State private var isTyping = false
    @State private var showChoices = false
    @State private var showEnding = false

    private let speed: TimeInterval = 0.03

    var body: some View {
        ZStack {
            immersiveDarkBG.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(DemoStory.title)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(ColorPalette.immersiveDarkText)
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("一个来自 StoryWeave 的示范故事")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(ColorPalette.immersiveDarkMuted)

                        Rectangle().fill(ColorPalette.immersiveDarkAccent).frame(height: 1.5).opacity(0.7)

                        Text(displayed)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(ColorPalette.immersiveDarkText)
                            .lineSpacing(8)
                            .tracking(0.3)

                        AIGeneratedBadge(compact: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 160)
                }
                .scrollDisabled(isTyping)
                .scrollIndicators(.hidden)

                choicesOverlay
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showChoices)
            }

            if showEnding { endingSheet.zIndex(3).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .onAppear { startTyping(for: 0) }
        .preferredColorScheme(.dark)
    }

    private var immersiveDarkBG: Color { ColorPalette.immersiveDarkBG }

    private var header: some View {
        HStack {
            Text("示范故事").font(.system(size: 13, design: .rounded)).foregroundStyle(ColorPalette.immersiveDarkAccent)
            Spacer()
            if !isTyping {
                Button("跳过") { finishDemo() }
                    .font(.system(size: 13)).foregroundStyle(ColorPalette.immersiveDarkMuted)
            }
        }.padding(.horizontal, 20).padding(.top, 12)
    }

    private func startTyping(for index: Int) {
        guard index < DemoStory.nodes.count else {
            showEnding = true; return
        }
        nodeIndex = index
        let node = DemoStory.nodes[index]
        displayed = ""; isTyping = true; showChoices = false
        Task { @MainActor in
            let chars = Array(node.content)
            for c in chars {
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                displayed += String(c)
            }
            isTyping = false
            withAnimation(.easeOut(duration: 0.3)) { showChoices = !node.choices.isEmpty }
            if node.choices.isEmpty {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                showEnding = true
            }
        }
    }

    // MARK: ③ 动作化选择 — 底部弹起 + 毛玻璃 + 琥珀金强调

    private var choicesOverlay: some View {
        Group {
            if showChoices {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("接下来……")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(ColorPalette.immersiveDarkMuted)
                            .padding(.leading, 8)
                        ForEach(Array(DemoStory.nodes[nodeIndex].choices.enumerated()), id: \.offset) { _, pair in
                            let (actionText, _) = pair
                            Button { startTyping(for: nodeIndex + 1) } label: {
                                HStack(spacing: 12) {
                                    Text("▸").foregroundStyle(ColorPalette.immersiveDarkAccent).font(.system(size: 13))
                                    Text(actionText)
                                        .font(.system(size: 15, design: .serif))
                                        .foregroundStyle(ColorPalette.immersiveDarkText)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(ColorPalette.immersiveDarkAccent.opacity(0.08))
                                )
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 20)
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(ColorPalette.immersiveDarkAccent.opacity(0.4), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 16).padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var endingSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(ColorPalette.immersiveDarkAccent)
            Text("示范故事结束了").font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(ColorPalette.immersiveDarkText)
            Text("现在，轮到你编织自己的故事了。")
                .font(.system(size: 14)).foregroundStyle(ColorPalette.immersiveDarkMuted)
            Button { finishDemo() } label: {
                HStack { Spacer(); Text("开始创作你的故事").font(.system(size: 16, weight: .semibold, design: .rounded)); Spacer() }
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorPalette.immersiveDarkAccent))
                    .foregroundStyle(ColorPalette.immersiveDarkBG)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 30).padding(.vertical, 30)
        .background(.ultraThickMaterial)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(ColorPalette.immersiveDarkAccent.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func finishDemo() {
        UserDefaults.standard.set(true, forKey: "onboarding.demo_seen")
        onFinish()
    }
}
