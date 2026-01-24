import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationStack {
            List {

                Section("Hesap") {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        Label("Profili Düzenle", systemImage: "person.crop.circle")
                    }
                }

                Section("Uygulama") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Hakkında", systemImage: "info.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
}
