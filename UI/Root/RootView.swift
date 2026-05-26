import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if !session.isAuthed {
                AuthLandingView()
            } else if session.currentProfile != nil || session.onboardingSkipped {
                // Profil tamamlandı veya kullanıcı kurulumu atlayıp ana sayfaya geçti
                MainTabView()
            } else {
                // Giriş yapıldı ama profil henüz oluşturulmadı → onboarding
                let isSocial = backendAuthProvider != "email"
                NavigationStack {
                    SignUpFlowView(
                        isSocialLogin: isSocial,
                        prefillName: isSocial ? session.socialLoginName : ""
                    )
                }
            }
        }
        .task {
            guard didBootstrap == false else { return }
            didBootstrap = true
            session.bootstrap(modelContext: modelContext)
        }
    }

    /// Backend kullanıcısının auth provider'ını döner
    private var backendAuthProvider: String {
        session.backendUser?.auth_provider ?? "email"
    }
}
