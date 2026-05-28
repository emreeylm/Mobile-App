import SwiftUI
import SwiftData
import AuthenticationServices
import GoogleSignIn

struct AuthLandingView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var animateGradient = false
    @State private var localError: String? = nil
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false
    @State private var isEmailLoginLoading = false
    @State private var navigateToSignUp = false
    @State private var showForgotPassword = false
    @State private var socialName: String = ""
    @State private var isSocialSignUp = false

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
                        Text("Binge")
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
                            .onChange(of: email) { _, _ in clearErrors() }

                        SecureField("Şifre", text: $password)
                            .textInputAutocapitalization(.never)
                            .modernInput(icon: "lock.fill")
                            .onChange(of: password) { _, _ in clearErrors() }

                        // Şifremi Unuttum linki
                        HStack {
                            Spacer()
                            Button { showForgotPassword = true } label: {
                                Text("Şifremi Unuttum")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .padding(.top, -8)

                        // Hata ve durum mesajları
                        errorSection

                        // Giriş Yap butonu
                        Button {
                            signIn()
                        } label: {
                            Group {
                                if isEmailLoginLoading {
                                    ProgressView()
                                        .tint(AppTheme.main)
                                } else {
                                    Text("Giriş Yap")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.main)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
                        .disabled(isEmailLoginLoading)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 24)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(AppTheme.text.opacity(0.15))
                        Text("veya").font(.caption).foregroundStyle(AppTheme.text.opacity(0.4))
                        Rectangle().frame(height: 1).foregroundStyle(AppTheme.text.opacity(0.15))
                    }
                    .padding(.horizontal, 24)

                    // Sign in with Apple
                    Group {
                        if isAppleLoading {
                            ProgressView().tint(AppTheme.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                Task { await handleAppleSignIn(result) }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: 50)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sign in with Google
                    Group {
                        if isGoogleLoading {
                            ProgressView().tint(AppTheme.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Button { signInWithGoogle() } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.black)
                                    Text("Google ile Giriş Yap")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.white)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Switch to Sign Up
                    Button {
                        isSocialSignUp = false
                        socialName = ""
                        navigateToSignUp = true
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
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpFlowView(
                    isSocialLogin: isSocialSignUp,
                    prefillName: socialName,
                    initialEmail: isSocialSignUp ? "" : email,
                    onBack: { navigateToSignUp = false }
                )
            }
        }
    }

    // MARK: - Hata / Durum Bölümü

    @ViewBuilder
    private var errorSection: some View {
        // Hesap bulunamadı → kayıt ol yönlendirmesi
        if session.accountNotFound {
            VStack(spacing: 6) {
                Text("Bu e-postaya ait hesap bulunamadı.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button {
                    isSocialSignUp = false
                    socialName = ""
                    navigateToSignUp = true
                } label: {
                    Text("Kayıt olmak ister misin?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .underline()
                }
            }
            .padding(.horizontal)
        }
        // Şifre / sunucu hatası
        else if let err = session.authErrorMessage {
            Text(err)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        // Yerel doğrulama hatası (boş alan vb.)
        else if let localErr = localError {
            Text(localErr)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Email Sign In

    private func signIn() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty else { localError = "E-posta adresini gir."; return }
        guard !p.isEmpty else { localError = "Şifreni gir."; return }

        localError = nil
        isEmailLoginLoading = true

        Task {
            defer { isEmailLoginLoading = false }
            await session.signIn(email: e, password: p, modelContext: modelContext)
        }
    }

    private func clearErrors() {
        localError = nil
        session.authErrorMessage = nil
        session.accountNotFound = false
    }

    // MARK: - Google Sign In Handler

    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else {
            localError = "Ekran bulunamadı."
            return
        }
        isGoogleLoading = true
        localError = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [self] result, err in
            DispatchQueue.main.async {
                isGoogleLoading = false
                if let err {
                    if (err as NSError).code == GIDSignInError.canceled.rawValue { return }
                    localError = err.localizedDescription
                    return
                }
                guard let idToken = result?.user.idToken?.tokenString else {
                    localError = "Google token alınamadı."
                    return
                }
                Task { @MainActor in
                    let name = result?.user.profile?.name ?? ""
                    let isNewUser = await session.socialLogin(
                        provider: "google",
                        idToken: idToken,
                        modelContext: modelContext
                    )
                    if isNewUser {
                        isSocialSignUp = true
                        socialName = name
                        session.socialLoginName = name   // RootView için de sakla
                        navigateToSignUp = true
                    }
                }
            }
        }
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let err):
            // Kullanıcı iptal ettiyse sessizce geç
            guard (err as? ASAuthorizationError)?.code != .canceled else { return }
            localError = err.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                localError = "Apple token alınamadı."
                return
            }
            isAppleLoading = true
            let isNewUser = await session.socialLogin(
                provider: "apple",
                idToken: idToken,
                modelContext: modelContext
            )
            isAppleLoading = false
            if isNewUser {
                isSocialSignUp = true
                socialName = credential.fullName.flatMap {
                    [$0.givenName, $0.familyName].compactMap { $0 }.joined(separator: " ")
                }.flatMap { $0.isEmpty ? nil : $0 } ?? ""
                navigateToSignUp = true
            }
        }
    }
}
