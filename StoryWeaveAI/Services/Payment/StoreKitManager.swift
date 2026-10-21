import Foundation
import StoreKit
import SwiftUI

// MARK: - StoreKit Manager
/// StoreKit 2 订阅与内购管理

@MainActor
final class StoreKitManager: ObservableObject {
    
    static let shared = StoreKitManager()
    
    // MARK: Published Properties
    
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: Set<String> = []
    @Published var purchasedConsumables: Set<String> = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: StoreKitError?
    
    // MARK: Subscription State
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: Init
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchaseState() }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: Product Loading
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: ProductIDs.allProductIDs)
            products.sort { (p1: Product, p2: Product) -> Bool in
                let p1IsSub = p1.type.rawValue == "subscription"
                let p2IsSub = p2.type.rawValue == "subscription"
                if p1IsSub && p2IsSub {
                    return p1.price < p2.price
                }
                if p1IsSub { return true }
                if p2IsSub { return false }
                return p1.price < p2.price
            }
        } catch {
            lastError = .productLoadFailed(error)
        }
    }
    
    /// 获取订阅产品
    var subscriptionProducts: [Product] {
        products.filter { ProductIDs.allSubscriptionIDs.contains($0.id) }
    }
    
    /// 获取消耗型内购产品
    var consumableProducts: [Product] {
        products.filter { ProductIDs.allConsumableIDs.contains($0.id) }
    }
    
    // MARK: Purchase
    
    /// 购买产品
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await handlePurchaseSuccess(transaction: transaction, product: product)
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            // 等待交易完成
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// 恢复购买
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchaseState()
    }
    
    // MARK: Purchase State
    
    func updatePurchaseState() async {
        purchasedSubscriptions.removeAll()
        purchasedConsumables.removeAll()
        
        // 检查当前有效订阅
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProductIDs.allSubscriptionIDs.contains(transaction.productID) {
                    purchasedSubscriptions.insert(transaction.productID)
                }
                if ProductIDs.allConsumableIDs.contains(transaction.productID) {
                    purchasedConsumables.insert(transaction.productID)
                }
            }
        }
        
        isPremium = !purchasedSubscriptions.isEmpty
        
        // 额外检查已购买但非当前订阅的产品（消耗型）
        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result {
                if ProductIDs.allConsumableIDs.contains(transaction.productID) {
                    purchasedConsumables.insert(transaction.productID)
                }
            }
        }
        
        // 持久化
        UserDefaults.standard.set(isPremium, forKey: "is_premium")
    }
    
    // MARK: Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updatePurchaseState()
                    await transaction.finish()
                }
            }
        }
    }
    
    // MARK: Helpers
    
    private func handlePurchaseSuccess(transaction: StoreKit.Transaction, product: Product) async throws {
        if ProductIDs.allSubscriptionIDs.contains(transaction.productID) {
            purchasedSubscriptions.insert(transaction.productID)
            isPremium = true
        } else {
            purchasedConsumables.insert(transaction.productID)
        }
        
        HapticManager.success()
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: Premium Check
    
    var hasActiveSubscription: Bool {
        return !purchasedSubscriptions.isEmpty
    }
    
    var premiumStatusText: String {
        if hasActiveSubscription {
            return "Premium 会员"
        } else {
            return "免费版"
        }
    }
    
    // MARK: Cancel
    
    func openManageSubscriptions() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case productLoadFailed(Error)
    case purchaseFailed(Error)
    case verificationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productLoadFailed(let error):
            return "加载产品失败：\(error.localizedDescription)"
        case .purchaseFailed(let error):
            return "购买失败：\(error.localizedDescription)"
        case .verificationFailed:
            return "交易验证失败"
        case .unknown:
            return "发生未知错误"
        }
    }
}
