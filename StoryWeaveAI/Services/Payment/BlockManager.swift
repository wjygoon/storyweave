import Foundation

// MARK: - Block Manager
/// 单机最小实现：屏蔽世界观模板 ID（来源 ID），Home 推荐流过滤

@MainActor
final class BlockManager: ObservableObject {
    static let shared = BlockManager()
    private static let k = "blocked.source.ids"

    @Published private(set) var blockedSourceIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(blockedSourceIDs), forKey: Self.k) }
    }

    private init() {
        let arr = UserDefaults.standard.array(forKey: Self.k) as? [String] ?? []
        self.blockedSourceIDs = Set(arr)
    }

    func isBlocked(sourceID: String) -> Bool { blockedSourceIDs.contains(sourceID) }
    func block(sourceID: String) { blockedSourceIDs.insert(sourceID) }
    func unblock(sourceID: String) { blockedSourceIDs.remove(sourceID) }
}
