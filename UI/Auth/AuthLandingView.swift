import SwiftUI
import SwiftData
import AuthenticationServices
import GoogleSignIn

struct AuthLandingView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false
    @State private var localError: String? = nil

    @State private var navigateToSignUp = false
    @State private var socialName: String = ""
    @State private var isSocialSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer(minLength: 80)

                    // Logo + Başlık
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

                    // Hata mesajı
                    if let err = localError ?? session.authErrorMessage {
                        Text(err)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Giriş Butonları
                    VStack(spacing: 16) {
                        // Apple ile Giriş
                        Group {
                            if isAppleLoading {
                                ProgressView().tint(AppTheme.text)
                                    .frame(maxWidth: .infinity).frame(height: 50)
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

                        // Google ile Giriş
                        Group {
                            if isGoogleLoading {
                                ProgressView().tint(AppTheme.text)
                                    .frame(maxWidth: .infinity).frame(height: 50)
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
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(.white)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpFlowView(
                    isSocialLogin: isSocialSignUp,
                    prefillName: socialName,
                    onBack: { navigateToSignUp = false }
                )
            }
        }
    }

    // MARK: - Google Sign In

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
                        session.socialLoginName = name
                        navigateToSignUp = true
                    }
                }
            }
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let err):
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
