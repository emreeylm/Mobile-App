import UIKit
import GoogleMobileAds
import GoogleSignIn
import os

/// APNs cihaz token'larını karşılar ve PushNotificationManager'a iletir.
final class AppDelegate: NSObject, UIApplicationDelegate {

    private let logger = Logger(subsystem: "com.bingedate", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MobileAds.shared.start(completionHandler: nil)

        // Google Sign-In — Info.plist'teki GIDClientID'yi oku ve yapılandır
        if let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String, !clientID.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            logger.error("GIDClientID bulunamadı — Build Settings'te GOOGLE_CLIENT_ID tanımlandı mı?")
        }

        return true
    }

    // Google Sign-In callback URL'sini yakala
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationError(error)
        }
    }
}
