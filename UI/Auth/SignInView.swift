import SwiftUI
import SwiftData

struct SignInView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 8) {
                Text("Tekrar Hoşgeldin!")
                    .modernFont(.largeTitle, weight: .bold)
                Text("Kaldığın yerden devam et")
                    .modernFont(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                TextField("E-posta", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .modernInput(icon: "envelope.fill")

                SecureField("Şifre", text: $password)
                    .textInputAutocapitalization(.never)
                    .modernInput(icon: "lock.fill")
            }
            .padding(.horizontal, 16)

            if let error {
                Text(error)
                    .modernFont(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .multilineTextAlignment(.center)
            }
            
            if let err = session.authErrorMessage {
                Text(err)
                    .modernFont(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
                let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !e.isEmpty else { error = "E-posta gir."; return }
                guard !p.isEmpty else { error = "Şifre gir."; return }
                error = nil
                session.signIn(email: e, password: p, modelContext: modelContext)
            } label: {
                Text("Giriş Yap")
            }
            .primaryButtonStyle()
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
