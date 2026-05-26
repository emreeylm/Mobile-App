import Foundation
import SwiftUI
import StoreKit
import Combine
import os

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "Free"
    case plus = "Plus"
    case gold = "Gold"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Binge Date Plus"
        case .gold: return "Binge Date Gold"
        }
    }

    var color: Color {
        switch self {
        case .free: return .gray
        case .plus: return Color(hex: "52C4C4")
        case .gold: return Color(hex: "F5E6C8")
        }
    }

    var iconName: String {
        switch self {
        case .free: return "person.fill"
        case .plus: return "star.fill"
        case .gold: return "crown.fill"
        }
    }
}

// MARK: - Subscription Store

@MainActor
final class AppSubscriptionStore: ObservableObject {

    // MARK: - Product IDs
    static let plusProductID = "com.bingedate.plus.monthly"
    static let goldProductID = "com.bingedate.gold.monthly"
    static let allProductIDs: Set<String> = [plusProductID, goldProductID]

    // MARK: - Published State

    @Published var tier: SubscriptionTier = .free
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    @Published var dailySwipesUsed: Int = 0
    @Published var dailySuperLikesUsed: Int = 0
    @Published var lastResetDate: Date = .now
    @Published var showPeriodicPaywall: Bool = false
        /// Yeni kayıt hoş geldin superlike'ı kullanıldı mı? (tek seferlik)
    @Published var welcomeSuperLikeUsed: Bool = false

    // Ürün yüklenemediğinde gösterilecek static fallback fiyatlar
    var plusFallbackPrice: String = "₺79,99"
    var goldFallbackPrice: String = "₺129,99"
    var isLoadingProducts: Bool = false

    private var actionCount = 0
    private var updateListenerTask: Task<Void, Error>?
    private let logger = Logger(subsystem: "com.bingedate", category: "StoreKit")

    // MARK: - Limits

    var swipeLimit: Int {
        switch tier {
        case .free: return 10
        case .plus, .gold: return Int.max
        }
    }

    var superLikeLimit: Int {
        switch tier {
        case .free: return 0   // Günlük hak yok; hoş geldin bonusu ayrı takip edilir
        case .plus: return 5
        case .gold: return Int.max
        }
    }

    var canSeeWhoLikedYou: Bool { tier != .free }
    var canRewind: Bool { tier != .free }
    var hasPriorityBoost: Bool { tier == .gold }
    var isPremium: Bool { tier != .free }

    var remainingSwipes: Int { max(0, swipeLimit - dailySwipesUsed) }
    var remainingSuperLikes: Int { max(0, superLikeLimit - dailySuperLikesUsed) }

    // MARK: - Init

    init() {
        loadDailyCounters()
        resetDailyCountersIfNeeded()
        updateListenerTask = startTransactionListener()
        Task { await loadProductsAndUpdateStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - StoreKit: Load Products

    func loadProductsAndUpdateStatus() async {
        isLoadingProducts = true
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { $0.price > $1.price }
            logger.info("Loaded \(fetched.count) products from App Store")
        } catch {
            logger.error("Product fetch failed: \(error)")
        }
        isLoadingProducts = false
        await refreshEntitlements()
    }

    // MARK: - StoreKit: Purchase

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await applyPurchase(tx)
                await tx.finish()
                logger.info("Purchase success: \(product.id)")
            case .userCancelled:
                logger.info("User cancelled purchase")
            case .pending:
                logger.info("Purchase pending approval")
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Purchase failed: \(error)")
        }
    }

    // MARK: - StoreKit: Restore

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            logger.info("Restore completed")
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Restore failed: \(error)")
        }
    }

    // MARK: - App Store Subscription Management

    func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Consumption Helpers

    func consumeSwipe() -> Bool {
        resetDailyCountersIfNeeded()
        guard dailySwipesUsed < swipeLimit else { return false }
        dailySwipesUsed += 1
        saveDailyCounters()
        return true
    }

    func consumeSuperLike() -> Bool {
        if tier == .free {
            // Ücretsiz kullanıcı: sadece hoş geldin bonusu (tek seferlik)
            guard !welcomeSuperLikeUsed else { return false }
            welcomeSuperLikeUsed = true
            saveDailyCounters()
            return true
        }
        // Premium kullanıcı: günlük limit
        resetDailyCountersIfNeeded()
        guard dailySuperLikesUsed < superLikeLimit else { return false }
        dailySuperLikesUsed += 1
        saveDailyCounters()
        return true
    }

    func addAdBonus() {
        dailySwipesUsed = max(0, dailySwipesUsed - 5)
        saveDailyCounters()
    }

    func recordAppInteraction() {
        guard tier == .free else { return }
        actionCount += 1
        if actionCount % 15 == 0 {
            showPeriodicPaywall = true
        }
    }

    // MARK: - Private: Transaction Listener

    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                do {
                    guard let self else { return }
                    let tx = try self.checkVerified(result)
                    await self.applyPurchase(tx)
                    await tx.finish()
                } catch {
                    self?.logger.error("Transaction listener error: \(error)")
                }
            }
        }
    }

    // MARK: - Private: Entitlement Check

    private func refreshEntitlements() async {
        var activeTier: SubscriptionTier = .free

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let tx = try checkVerified(result)
                if tx.revocationDate == nil {
                    if tx.productID == Self.goldProductID {
                        activeTier = .gold
                    } else if tx.productID == Self.plusProductID, activeTier != .gold {
                        activeTier = .plus
                    }
                }
            } catch {
                logger.error("Entitlement verification failed: \(error)")
            }
        }

        let previousTier = tier
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            tier = activeTier
        }
        saveTier()
        logger.info("Subscription status: \(activeTier.rawValue)")
        if activeTier != previousTier {
            await syncPremiumToBackend(isPremium: activeTier != .free)
        }
    }

    // MARK: - Private: Apply Purchase

    private func applyPurchase(_ tx: StoreKit.Transaction) async {
        if tx.productID == Self.goldProductID {
            tier = .gold
        } else if tx.productID == Self.plusProductID {
            tier = .plus
        }
        saveTier()
        await syncPremiumToBackend(isPremium: tier != .free)
    }

    private func syncPremiumToBackend(isPremium: Bool) async {
        do {
            _ = try await APIClient.shared.updateMe(UpdateUserRequest(is_premium: isPremium))
            logger.info("Backend premium sync: \(isPremium)")
        } catch {
            logger.error("Backend premium sync failed: \(error)")
        }
    }

    // MARK: - Private: Verify

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    // MARK: - Persistence

    static let tierKey = "subscription.tier"
    private let swipesUsedKey          = "subscription.swipesUsed"
    private let superLikesKey          = "subscription.superLikesUsed"
    private let resetDateKey           = "subscription.lastResetDate"
    private let welcomeSuperLikeKey    = "subscription.welcomeSuperLikeUsed"

    private func saveTier() {
        KeychainManager.shared.save(tier.rawValue, for: Self.tierKey)
    }

    private func saveDailyCounters() {
        UserDefaults.standard.set(dailySwipesUsed, forKey: swipesUsedKey)
        UserDefaults.standard.set(dailySuperLikesUsed, forKey: superLikesKey)
        UserDefaults.standard.set(lastResetDate, forKey: resetDateKey)
        UserDefaults.standard.set(welcomeSuperLikeUsed, forKey: welcomeSuperLikeKey)
    }

    private func loadDailyCounters() {
        if let raw = KeychainManager.shared.load(for: Self.tierKey),
           let saved = SubscriptionTier(rawValue: raw) {
            tier = saved
        }
        dailySwipesUsed      = UserDefaults.standard.integer(forKey: swipesUsedKey)
        dailySuperLikesUsed  = UserDefaults.standard.integer(forKey: superLikesKey)
        welcomeSuperLikeUsed = UserDefaults.standard.bool(forKey: welcomeSuperLikeKey)
        if let saved = UserDefaults.standard.object(forKey: resetDateKey) as? Date {
            lastResetDate = saved
        }
    }

    private func resetDailyCountersIfNeeded() {
        guard !Calendar.current.isDateInToday(lastResetDate) else { return }
        dailySwipesUsed     = 0
        dailySuperLikesUsed = 0
        lastResetDate       = .now
        saveDailyCounters()
    }
}
