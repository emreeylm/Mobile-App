import SwiftUI
import SwiftData

@main
struct DateAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var session = SessionStore()
    @StateObject private var subscriptionStore = AppSubscriptionStore()
    private let container: ModelContainer = AppModelContainer.make(inMemory: false)

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(session)
                .environmentObject(subscriptionStore)
                .onAppear {
                    DemoSeeder.seedIfNeeded(context: container.mainContext)
                    LocationManager.shared.requestPermission()
                    Task { await PushNotificationManager.shared.requestPermission() }
                }
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    PushNotificationManager.shared.resetBadge()
                }
        }
    }
}
