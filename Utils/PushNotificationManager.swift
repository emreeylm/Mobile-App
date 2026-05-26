import Foundation
import UserNotifications
import UIKit
import os

/// APNs cihaz token kaydı ve bildirim yönlendirmesini yönetir.
@MainActor
final class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()
    private let logger = Logger(subsystem: "com.bingedate", category: "PushNotifications")

    private override init() {
        super.init()
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                logger.info("Push notification permission granted")
            } else {
                logger.info("Push notification permission denied")
            }
        } catch {
            logger.error("Push notification authorization failed: \(error)")
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            do {
                try await APIClient.shared.registerDeviceToken(token)
                logger.info("Device token registered with backend")
            } catch {
                logger.error("Device token backend registration failed: \(error)")
            }
        }
    }

    func handleRegistrationError(_ error: Error) {
        logger.error("APNs registration error: \(error)")
    }

    func resetBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    // Uygulama ön plandayken bildirim göster
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    // Kullanıcı bildirime tıkladığında deep link
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "match":
            NotificationCenter.default.post(name: .didReceiveMatchPush, object: nil, userInfo: userInfo)
        case "message":
            NotificationCenter.default.post(name: .didReceiveMessagePush, object: nil, userInfo: userInfo)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didReceiveMatchPush   = Notification.Name("com.bingedate.matchPush")
    static let didReceiveMessagePush = Notification.Name("com.bingedate.messagePush")
}
