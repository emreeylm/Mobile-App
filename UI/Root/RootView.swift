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
                    VStack(spacing: 20) {
                        Text("Profil bulunamadı.")
                            .foregroundStyle(.secondary)
                        Button("Çıkış Yap") { 
                            session.signOut() 
                        }
                        .buttonStyle(.bordered)
                    }
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
