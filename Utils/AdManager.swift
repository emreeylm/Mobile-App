import Foundation
import UIKit
import Combine
import os

/// Rewarded reklam yaşam döngüsünü soyutlayan protokol.
/// GoogleMobileAds veya AppLovin MAX SDK'yı bu protokol üzerinden bağla.
protocol RewardedAdProvider: AnyObject {
    var isReady: Bool { get }
    /// Reklam yüklenip hazır olduğunda çağrılır. AdManager bu callback'i ayarlar.
    var onReady: (() -> Void)? { get set }
    func load(adUnitID: String)
    func show(from viewController: UIViewController, completion: @escaping (Bool) -> Void)
}

/// Rewarded ad yöneticisi — backend /ad/reward endpoint'iyle entegre.
@MainActor
final class AdManager: NSObject, ObservableObject {

    static let shared = AdManager()
    private let logger = Logger(subsystem: "com.bingedate", category: "AdManager")

    /// Gerçek SDK entegrasyonu için bu property'yi ayarla:
    ///   AdManager.shared.provider = GADRewardedAdProvider(adUnitID: "ca-app-pub-xxx/yyy")
    ///   AdManager.shared.provider = MARewardedAdProvider(adUnitID: "ad_unit_id")
    var provider: RewardedAdProvider?

    private var isShowingAd = false

    /// SwiftUI view'ların reaktif olarak takip edebileceği reklam hazırlık durumu.
    /// Provider reklam yüklediğinde `true`, reklam gösterilmeye başladığında `false` olur.
    @Published private(set) var canShowAd: Bool = false

    private override init() {
        super.init()
        let p = GADRewardedAdProvider()
        p.onReady = { [weak self] in
            Task { @MainActor [weak self] in
                self?.canShowAd = true
                self?.logger.info("Rewarded ad hazır — buton aktifleşti.")
            }
        }
        provider = p
        loadAd()
    }

    // MARK: - Public API

    /// Reklamı yükler. Genellikle app başlarken veya önceki reklam kapandıktan sonra çağrılır.
    func loadAd() {
        guard let adUnitID else {
            logger.warning("BINGE_DATE_AD_UNIT_ID ayarlanmamış, reklam yüklenemez")
            return
        }
        provider?.load(adUnitID: adUnitID)
        logger.info("Rewarded ad yükleniyor...")
    }

    /// Reklamı gösterir. Kullanıcı izlerse backend'e reward isteği atar.
    /// - Parameter completion: (rewarded: Bool) — bonus verilip verilmediği
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard !isShowingAd else { completion(false); return }

        guard let provider, provider.isReady else {
            logger.warning("Rewarded ad hazır değil")
            completion(false)
            return
        }

        isShowingAd = true
        canShowAd = false   // Reklam başlıyor; buton pasifleşir
        provider.show(from: viewController) { [weak self] earned in
            guard let self else { return }
            self.isShowingAd = false
            if earned {
                self.claimReward(completion: completion)
            } else {
                completion(false)
            }
            // Sonraki gösterim için önceden yükle — yüklenince canShowAd tekrar true olur
            self.loadAd()
        }
    }

    // MARK: - Private

    private var adUnitID: String? {
        Bundle.main.infoDictionary?["BINGE_DATE_AD_UNIT_ID"] as? String
    }

    private func claimReward(completion: @escaping (Bool) -> Void) {
        completion(true)   // Lokal ödülü hemen ver; backend senkronizasyonu fire-and-forget
        Task {
            do {
                let resp = try await APIClient.shared.adReward()
                logger.info("Ad reward synced — kalan_hak: \(resp.kalan_hak)")
            } catch {
                logger.error("Ad reward backend sync failed (lokal ödül verildi): \(error)")
            }
        }
    }
}

// MARK: - Mock provider (test / SDK yok ortamı)

/// Gerçek SDK bağlanmadan önce test amacıyla kullanılabilir.
final class MockRewardedAdProvider: RewardedAdProvider {
    var isReady: Bool = false
    var onReady: (() -> Void)?

    func load(adUnitID: String) {
        // Mock: kısa gecikme sonrası hazır
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isReady = true
            self?.onReady?()
        }
    }

    func show(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        isReady = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(true) // Her zaman ödül ver (test)
        }
    }
}
