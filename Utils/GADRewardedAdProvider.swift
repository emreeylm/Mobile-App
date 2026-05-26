import Foundation
import GoogleMobileAds
import UIKit
import os

/// GoogleMobileAds (AdMob) v11+ tabanlı rewarded ad provider.
/// `RewardedAdProvider` protokolünü `RewardedAd` API'siyle implement eder.
@MainActor
final class GADRewardedAdProvider: NSObject, RewardedAdProvider {

    private var rewardedAd: RewardedAd?
    private var showCompletion: ((Bool) -> Void)?
    private var didEarnReward = false
    private let logger = Logger(subsystem: "com.bingedate", category: "GADRewardedAdProvider")

    // MARK: - RewardedAdProvider

    var isReady: Bool { rewardedAd != nil }
    /// AdManager tarafından ayarlanır; reklam yüklenince çağrılır.
    var onReady: (() -> Void)?

    func load(adUnitID: String) {
        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                self.logger.error("Rewarded ad yüklenemedi: \(error.localizedDescription)")
                return
            }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.logger.info("Rewarded ad hazır.")
            // AdManager'ı bilgilendir → canShowAd = true
            self.onReady?()
        }
    }

    func show(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            logger.warning("show() çağrıldı ama rewardedAd nil")
            completion(false)
            return
        }
        showCompletion = completion
        didEarnReward = false
        ad.present(from: viewController) { [weak self] in
            // userDidEarnRewardHandler — reklam kapanmadan önce çağrılır
            self?.didEarnReward = true
        }
    }
}

// MARK: - FullScreenContentDelegate
// ObjC protokol callback'leri main thread garantisi vermez → nonisolated + Task @MainActor

extension GADRewardedAdProvider: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.rewardedAd = nil          // Tek kullanımlık; bir sonraki gösterim için sıfırla
            let earned = self.didEarnReward
            self.showCompletion?(earned)
            self.showCompletion = nil
            self.logger.info("Reklam kapandı — ödül kazanıldı: \(earned)")
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.rewardedAd = nil
            self.showCompletion?(false)
            self.showCompletion = nil
            self.logger.error("Reklam gösterilemedi: \(error.localizedDescription)")
        }
    }
}
