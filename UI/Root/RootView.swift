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
                // Lokal profil var ya da kullanıcı kurulumu atladı → ana sayfa
                MainTabView()
            } else {
                // Giriş yapıldı ama lokal profil yok → kayıt akışı
                // (backendOnboardingDone olsa bile; profil olmadan MainTabView kırılır)
                NavigationStack {
                    SignUpFlowView(
                        isSocialLogin: true,
                        prefillName: session.backendUser?.isim ?? session.socialLoginName
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

}
