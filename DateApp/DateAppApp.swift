import SwiftUI
import SwiftData

@main
struct DateAppApp: App {

    @StateObject private var session = SessionStore()
    private let container: ModelContainer = AppModelContainer.make(inMemory: false)

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(session)
                .onAppear {
                    // ✅ App Init Seeding
                    DemoSeeder.seedIfNeeded(context: container.mainContext)
                }
                .preferredColorScheme(.dark) // ✅ Enforce Makromusic Dark Theme
        }
    }
}
