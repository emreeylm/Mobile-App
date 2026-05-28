import SwiftUI
import SwiftData
import AuthenticationServices
import GoogleSignIn

struct AuthLandingView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    // Auth adımı
    private enum AuthStep { case phone, otp }
    @State private var step: AuthStep = .phone

    // Giriş verileri
    @State private var phone: String = ""        // 10 haneli (0532 xxx xx xx formatında)
    @State private var otpCode: String = ""      // 6 haneli

    // Yükleme / hata
    @State private var isLoading = false
    @State private var localError: String? = nil
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false

    // OTP geri sayım (120 sn)
    @State private var countdown: Int = 120
    @State private var countdownTimer: Timer? = nil

    // Demo modda backend sıfırlama kodunu tutar
    @State private var demoOTP: String? = nil

    // Onboarding yönlendirme
    @State private var navigateToSignUp = false
    @State private var socialName: String = ""
    @State private var isSocialSignUp = false

    /// Backend'e gönderilecek E.164 formatındaki numara
    private var e164Phone: String {
        // Kullanıcı 05xx veya 5xx girebilir; başındaki 0'ı at, +90 ekle
        let digits = phone.filter { $0.isNumber }
        if digits.hasPrefix("0") {
            return "+90" + digits.dropFirst()
        }
        return "+90" + digits
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 40)

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

                    // Form Kartı
                    VStack(spacing: 16) {
                        if step == .phone {
                            phoneStep
                        } else {
                            otpStep
                        }

                        // Hata mesajı
                        if let err = localError ?? session.authErrorMessage {
                            Text(err)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Ana buton
                        Button { handlePrimary() } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(AppTheme.main)
                                } else {
                                    Text(step == .phone ? "Kodu Gönder" : "Doğrula")
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
                        .disabled(isLoading)

                        // Geri / Tekrar Gönder
                        if step == .otp {
                            otpFooter
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 24)

                    // Veya ayraç
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(AppTheme.text.opacity(0.15))
                        Text("veya").font(.caption).foregroundStyle(AppTheme.text.opacity(0.4))
                        Rectangle().frame(height: 1).foregroundStyle(AppTheme.text.opacity(0.15))
                    }
                    .padding(.horizontal, 24)

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
                    .padding(.horizontal, 24)

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

    // MARK: - Phone Step

    private var phoneStep: some View {
        VStack(spacing: 14) {
            // +90 prefix + numara
            HStack(spacing: 0) {
                Text("+90")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(AppTheme.surface.opacity(0.6))

                TextField("5xx xxx xx xx", text: $phone)
                    .keyboardType(.phonePad)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .onChange(of: phone) { _, new in
                        // Sadece rakam, max 11 hane (05xx... veya 5xx...)
                        let digits = new.filter { $0.isNumber }
                        if digits.count <= 11 { phone = digits }
                        else { phone = String(digits.prefix(11)) }
                        clearErrors()
                    }
            }
            .background(AppTheme.surface.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - OTP Step

    private var otpStep: some View {
        VStack(spacing: 12) {
            Text("Telefon numarana gönderilen 6 haneli kodu gir.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.text.opacity(0.6))
                .multilineTextAlignment(.center)

            // Demo token göster
            if let demo = demoOTP {
                VStack(spacing: 4) {
                    Text("Demo Mod — Kod:")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                    Text(demo)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(AppTheme.accent)
                        .onTapGesture { otpCode = demo }
                }
                .padding(10)
                .background(AppTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            TextField("______", text: $otpCode)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .tracking(12)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.surface.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: otpCode) { _, new in
                    let digits = new.filter { $0.isNumber }
                    otpCode = String(digits.prefix(6))
                    clearErrors()
                }
        }
    }

    private var otpFooter: some View {
        HStack(spacing: 20) {
            // Geri
            Button {
                stopCountdown()
                withAnimation { step = .phone }
                otpCode = ""
                demoOTP = nil
                clearErrors()
            } label: {
                Text("← Geri")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.5))
            }

            Spacer()

            // Tekrar Gönder
            if countdown > 0 {
                Text("\(countdown)sn")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.text.opacity(0.4))
            } else {
                Button {
                    requestOTP()
                } label: {
                    Text("Tekrar Gönder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func handlePrimary() {
        clearErrors()
        if step == .phone {
            requestOTP()
        } else {
            verifyOTP()
        }
    }

    private func requestOTP() {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 9 else {
            localError = "Geçerli bir telefon numarası gir."
            return
        }

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let resp = try await APIClient.shared.requestPhoneOTP(telefon: e164Phone)
                if resp.sent {
                    demoOTP = resp.otp_code  // demo modda dolu
                    withAnimation { step = .otp }
                    startCountdown()
                }
            } catch let error as APIError {
                if case .httpError(429, _) = error {
                    localError = "Çok sık istek. 1 dakika bekleyip tekrar dene."
                } else {
                    localError = "SMS gönderilemedi. Bağlantını kontrol et."
                }
            } catch {
                localError = "Bağlantı hatası."
            }
        }
    }

    private func verifyOTP() {
        guard otpCode.count == 6 else {
            localError = "6 haneli kodu tam gir."
            return
        }

        isLoading = true
        Task {
            defer { isLoading = false }
            let isNew = await session.verifyPhoneOTP(
                telefon: e164Phone,
                code: otpCode,
                modelContext: modelContext
            )
            if session.isAuthed {
                stopCountdown()
                if isNew {
                    navigateToSignUp = true
                }
                // isNew=false → RootView isAuthed değişikliğini izler, otomatik yönlendirir
            }
        }
    }

    // MARK: - Countdown Timer

    private func startCountdown() {
        countdown = 120
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 { countdown -= 1 }
            else { stopCountdown() }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func clearErrors() {
        localError = nil
        session.authErrorMessage = nil
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
                        session.socialLoginName = name
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
