import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if session.isAuthed == false {
                AuthLandingView()
            } else {
                if session.currentProfile == nil {
                    // Kayıt olduktan sonra ProfileSetup’a gitmek yerine,
                    // artık kayıt akışı profili zaten oluşturuyor.
                    // Yine de güvenli fallback:
                    ProfileSetupView()
                } else {
                    MainTabView()
                }
            }
        }
        .task {
            guard didBootstrap == false else { return }
            didBootstrap = true
            session.bootstrap(modelContext: modelContext)
        }
    }
}
