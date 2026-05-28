import SwiftUI

// MARK: - ForgotPasswordView

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    // Step 1: Enter email → Step 2: Enter code + new password
    @State private var step: Step = .email
    @State private var email: String = ""
    @State private var resetCode: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var isLoading = false

    // Demo: backend returns token directly when DEMO_RESET_TOKENS=true
    @State private var demoToken: String? = nil

    enum Step { case email, code }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Icon + Title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "key.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundColor(AppTheme.accent)
                            }
                            .padding(.top, 32)

                            Text(step == .email ? "Şifreni Mi Unuttun?" : "Yeni Şifre Belirle")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.text)

                            Text(step == .email
                                 ? "E-posta adresini gir, sıfırlama kodunu gönderelim."
                                 : "E-postana gelen kodu ve yeni şifreni gir.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(AppTheme.text.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Form
                        VStack(spacing: 14) {
                            if step == .email {
                                emailStepFields
                            } else {
                                codeStepFields
                            }

                            // Error / Success
                            if let err = errorMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text(err)
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            }

                            if let ok = successMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text(ok)
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.green.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            }

                            // Demo token helper
                            if let token = demoToken, step == .code {
                                VStack(spacing: 4) {
                                    Text("Demo Modu — Sıfırlama Kodun:")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.text.opacity(0.4))
                                    Text(token)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(AppTheme.accent)
                                        .onTapGesture { resetCode = token }
                                }
                                .padding(10)
                                .background(AppTheme.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                            }

                            // Primary action button
                            Button { handlePrimary() } label: {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(AppTheme.main)
                                    } else {
                                        Text(step == .email ? "Kodu Gönder" : "Şifremi Sıfırla")
                                            .font(.headline)
                                            .foregroundColor(AppTheme.main)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                            }
                            .disabled(isLoading)

                            // Back to login
                            Button { dismiss() } label: {
                                Text("Girişe Dön")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.text.opacity(0.55))
                            }
                            .padding(.top, 4)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Step 1: Email fields

    private var emailStepFields: some View {
        TextField("E-posta adresi", text: $email)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .modernInput(icon: "envelope.fill")
            .onChange(of: email) { _, _ in clearMessages() }
    }

    // MARK: - Step 2: Code + new password fields

    private var codeStepFields: some View {
        VStack(spacing: 14) {
            TextField("Sıfırlama kodu", text: $resetCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modernInput(icon: "number")
                .onChange(of: resetCode) { _, _ in clearMessages() }

            SecureField("Yeni şifre", text: $newPassword)
                .textInputAutocapitalization(.never)
                .modernInput(icon: "lock.fill")
                .onChange(of: newPassword) { _, _ in clearMessages() }

            SecureField("Yeni şifreyi tekrar gir", text: $confirmPassword)
                .textInputAutocapitalization(.never)
                .modernInput(icon: "lock.rotation")
                .onChange(of: confirmPassword) { _, _ in clearMessages() }
        }
    }

    // MARK: - Actions

    private func handlePrimary() {
        clearMessages()
        if step == .email {
            sendCode()
        } else {
            resetPassword()
        }
    }

    private func sendCode() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "E-posta adresini gir."
            return
        }
        guard trimmed.contains("@") else {
            errorMessage = "Geçerli bir e-posta adresi gir."
            return
        }

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let resp = try await APIClient.shared.forgotPassword(email: trimmed)
                if resp.sent {
                    demoToken = resp.reset_token  // demo modda dolu, prod'da nil
                    withAnimation {
                        successMessage = demoToken != nil
                            ? "Kod hazır! Aşağıdaki kodu kopyala."
                            : "Sıfırlama kodu e-posta adresine gönderildi."
                        step = .code
                    }
                }
            } catch {
                errorMessage = "İstek gönderilemedi. Bağlantını kontrol et."
            }
        }
    }

    private func resetPassword() {
        let code = resetCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let conf = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !code.isEmpty else { errorMessage = "Sıfırlama kodunu gir."; return }
        guard !pass.isEmpty else { errorMessage = "Yeni şifreni gir."; return }
        guard pass.count >= 6 else { errorMessage = "Şifre en az 6 karakter olmalı."; return }
        guard pass == conf else { errorMessage = "Şifreler eşleşmiyor."; return }

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let resp = try await APIClient.shared.resetPassword(token: code, newPassword: pass)
                if resp.success {
                    successMessage = "Şifren başarıyla sıfırlandı. Giriş yapabilirsin."
                    // Small delay then dismiss
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    dismiss()
                }
            } catch let error as APIError {
                if case .httpError(400, _) = error {
                    errorMessage = "Geçersiz veya süresi dolmuş kod. Yeni kod talep et."
                } else {
                    errorMessage = "Şifre sıfırlanamadı. Tekrar dene."
                }
            } catch {
                errorMessage = "Bağlantı hatası. Tekrar dene."
            }
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
