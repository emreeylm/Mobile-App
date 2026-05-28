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
                // Kullanıcı phone OTP veya sosyal giriş ile zaten auth oldu.
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
