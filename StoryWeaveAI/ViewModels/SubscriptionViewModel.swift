import Foundation
import SwiftUI
import StoreKit

// MARK: - Subscription ViewModel

@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var purchaseSuccess: Bool = false
    
    // MARK: Properties
    
    private let storeKit = StoreKitManager.shared
    
    var isPremium: Bool {
        storeKit.isPremium
    }
    
    var monthlyProduct: Product? {
        storeKit.subscriptionProducts.first { $0.id == ProductIDs.monthly }
    }
    
    var yearlyProduct: Product? {
        storeKit.subscriptionProducts.first { $0.id == ProductIDs.yearly }
    }
    
    // MARK: Purchase
    
    func purchaseMonthly() async {
        guard let product = monthlyProduct else {
            errorMessage = "月付产品暂不可用"
            return
        }
        await performPurchase(product)
    }
    
    func purchaseYearly() async {
        guard let product = yearlyProduct else {
            errorMessage = "年付产品暂不可用"
            return
        }
        await performPurchase(product)
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await storeKit.restorePurchases()
            HapticManager.success()
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
    
    private func performPurchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await storeKit.purchase(product)
            isLoading = false
            
            if success {
                purchaseSuccess = true
            }
        } catch let error as StoreKitError {
            isLoading = false
            errorMessage = error.localizedDescription
        } catch {
            isLoading = false
            errorMessage = "购买失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: Info
    
    func openManageSubscriptions() {
        storeKit.openManageSubscriptions()
    }
}
