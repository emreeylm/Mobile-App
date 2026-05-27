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
            } else if session.currentProfile != nil || session.onboardingSkipped || session.backendOnboardingDone {
                // Profil tamamlandı, kurulum atlandı veya backend'de onboarding kaydı var
                MainTabView()
            } else {
                // Giriş yapıldı ama profil henüz oluşturulmadı → onboarding
                // isSocialLogin her zaman true: kullanıcı zaten auth oldu,
                // email/şifre adımlarını tekrar göstermeye gerek yok.
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
