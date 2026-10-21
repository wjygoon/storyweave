import SwiftUI

// MARK: - Share Card View
/// 生成精美的分享卡片，支持分享和保存到相册

struct ShareCardView: View {
    
    let story: Story
    @Environment(\.dismiss) private var dismiss
    @State private var exportText: String = ""
    @State private var isExporting: Bool = false
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    shareCardPreview
                    
                    actionButtons
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            }
            .navigationTitle("分享故事")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                if !exportText.isEmpty {
                    ShareSheet(items: [exportText])
                }
            }
            .task {
                await loadStoryText()
            }
        }
    }
    
    // MARK: Share Card Preview
    
    private var shareCardPreview: some View {
        ShareCardRenderable(
            story: story,
            nodes: story.nodes.suffix(5)
        )
        .aspectRatio(3/4, contentMode: .fit)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton("分享给好友", icon: "square.and.arrow.up") {
                showShareSheet = true
            }
            
            SecondaryButton("保存到相册", icon: "photo.on.rectangle") {
                Task { @MainActor in
                    saveCardToPhotos()
                }
            }
        }
    }
    
    // MARK: Helpers
    
    private func loadStoryText() async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            exportText = try await DataManager.shared.exportStoryAsText(story)
        } catch {
            exportText = "《\(story.displayTitle)》- StoryWeave AI 互动故事"
        }
    }
    
    @MainActor
    private func saveCardToPhotos() {
        let renderer = ImageRenderer(content: ShareCardRenderable(story: story, nodes: story.nodes.suffix(5)))
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(width: 360, height: 480)
        
        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            HapticManager.success()
        }
    }
}

// MARK: - Share Card Renderable

struct ShareCardRenderable: View {
    
    let story: Story
    let nodes: [StoryNode]
    
    var body: some View {
        ZStack {
            ColorPalette.darkGradient
            
            VStack(alignment: .leading, spacing: 16) {
                // 装饰性元素
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorPalette.primary.opacity(0.5))
                }
                
                // 标题区
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(WorldTemplate.template(with: story.worldTemplate)?.emoji ?? "📖")
                            .font(.system(size: 28))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.displayTitle)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 8) {
                                Text(WorldTemplate.template(with: story.worldTemplate)?.name ?? story.worldTemplate)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(ColorPalette.primary.opacity(0.3)))
                                
                                Text(story.storyStyle.displayName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorPalette.textSecondaryOnDark)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 内容预览
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(nodes.prefix(2).enumerated()), id: \.element.id) { _, node in
                        Text(node.content.prefix(100) + (node.content.count > 100 ? "..." : ""))
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(ColorPalette.textOnDark.opacity(0.8))
                            .lineLimit(3)
                        
                        if nodes.prefix(2).last?.id != node.id {
                            Rectangle()
                                .fill(ColorPalette.primary.opacity(0.2))
                                .frame(height: 1)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
                )
                
                Spacer()
                
                // 底部品牌信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorPalette.primary)
                            Text("StoryWeave")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        
                        HStack { AIGeneratedBadge(compact: false); Spacer() }
                            .font(.system(size: 10))
                            .foregroundStyle(ColorPalette.textSecondaryOnDark)
                    }
                    
                    Spacer()
                    
                    // 二维码占位
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "qrcode")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 360, height: 480)
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
