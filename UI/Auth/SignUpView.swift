import SwiftUI
import SwiftData

struct SignUpView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 8) {
                Text("Aramıza Katıl")
                    .modernFont(.largeTitle, weight: .bold)
                Text("Hemen hesabını oluştur")
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
                    .modernFont(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                signUp()
            } label: {
                Text("Kayıt Ol")
            }
            .primaryButtonStyle()
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard e.isEmpty == false else { error = "E-posta gir."; return }
        guard p.isEmpty == false else { error = "Şifre gir."; return }

        error = nil
        session.signUp(email: e, password: p, modelContext: modelContext)
    }
}
