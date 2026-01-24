import SwiftUI
import SwiftData

struct AuthLandingView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var animateGradient = false
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("DateApp")
                            .font(.system(size: 60, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.text)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Dizi & film zevkine göre\neşleşmenin yeni yolu.")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.text.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Form Card
                    VStack(spacing: 16) {
                        TextField("E-posta", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .modernInput(icon: "envelope.fill")

                        SecureField("Şifre", text: $password)
                            .textInputAutocapitalization(.never)
                            .modernInput(icon: "lock.fill")
                            
                        if let error {
                            Text(error)
                                .modernFont(.callout)
                                .foregroundStyle(AppTheme.text)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let err = session.authErrorMessage {
                            Text(err)
                                .modernFont(.callout)
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            signIn()
                        } label: {
                            Text("Giriş Yap")
                                .font(.headline)
                                .foregroundStyle(AppTheme.main)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 24)

                    Spacer()

                    // Switch to Sign Up
                    NavigationLink {
                        SignUpFlowView()
                    } label: {
                        HStack {
                            Text("Hesabın yok mu?")
                                .foregroundStyle(AppTheme.text.opacity(0.6))
                            Text("Kayıt Ol")
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.text)
                                .underline()
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func signIn() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !e.isEmpty else { error = "E-posta gir."; return }
        guard !p.isEmpty else { error = "Şifre gir."; return }
        error = nil
        
        session.signIn(email: e, password: p, modelContext: modelContext)
    }
}
