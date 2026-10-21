import SwiftUI

// MARK: - Typewriter Text
// Character-by-character reveal for dramatic narrative effect.

struct TypewriterText: View {
    let text: String
    @Binding var isComplete: Bool
    @State private var displayed: String = ""
    @State private var charIndex = 0
    var speed: TimeInterval = 0.025
    /// 打字过程中周期性回调（每 3 个字符），用于外部跟随滚动
    var onTick: (() -> Void)? = nil

    var body: some View {
        Text(displayed)
            .onChange(of: text) { _, _ in
                displayed = ""
                charIndex = 0
                isComplete = false
                startTyping()
            }
            .onAppear {
                if displayed.isEmpty { startTyping() }
            }
    }

    private func startTyping() {
        Task { @MainActor in
            let chars = Array(text)
            while charIndex < chars.count {
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                displayed += String(chars[charIndex])
                charIndex += 1
                if charIndex % 3 == 0 { onTick?() }
            }
            isComplete = true
        }
    }
}
