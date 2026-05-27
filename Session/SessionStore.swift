import Foundation
import SwiftData
import Combine
import os

@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Auth State

    @Published var isAuthed: Bool = false
    @Published var currentUserId: String? = nil

    // MARK: - Profile State

    @Published var currentProfile: Profile? = nil

    // MARK: - Backend User (API'den gelen)
    @Published var backendUser: UserResponse? = nil

    // MARK: - Onboarding
    /// Kullanıcı profil kurulumunu atlayarak ana sayfaya geçmek istedi
    @Published var onboardingSkipped: Bool = false
    /// Sosyal giriş (Google/Apple) ile yeni kullanıcı oluşturuldu
    @Published var socialLoginName: String = ""

    /// Backend'de onboarding tamamlandıysa true döner.
    /// Kayıt sırasında cinsiyet "belirtilmedi" atanır; onboarding sonrası gerçek değer yazılır.
    var backendOnboardingDone: Bool {
        guard let user = backendUser else { return false }
        return user.cinsiyet != "belirtilmedi" && user.hedef_cinsiyet != "belirtilmedi"
    }

    // MARK: - UI State (opsiyonel)

    @Published var authErrorMessage: String? = nil
    /// Login sırasında kayıtlı hesap bulunamazsa true (HTTP 404)
    @Published var accountNotFound: Bool = false


    private let keychain = KeychainManager.shared
    private let api = APIClient.shared
    private let logger = Logger(subsystem: "com.bingedate", category: "SessionStore")

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUnauthorizedNotification), name: NSNotification.Name("unauthorizedAPIResponse"), object: nil)
    }

    // MARK: - Bootstrap

    /// App açılınca çağrılır: önce Keychain'e bakar (gerçek token), yoksa UserDefaults'a (demo)
    func bootstrap(modelContext: ModelContext) {
        if let uid = keychain.load(for: KeychainManager.userIdKey), !uid.isEmpty {
            isAuthed = true
            currentUserId = uid
            loadMyProfile(modelContext: modelContext)
            Task { await fetchBackendUser() }
        } else {
            isAuthed = false
            currentUserId = nil
            currentProfile = nil
        }
    }

    // MARK: - Real Backend Auth

    /// Apple veya Google id_token ile backend'e giriş yapar.
    /// Tokenları Keychain'e kaydeder; is_new_user true ise onboarding gerekli.
    @discardableResult
    func socialLogin(provider: String, idToken: String, modelContext: ModelContext) async -> Bool {
        do {
            let resp = try await api.socialLogin(provider: provider, idToken: idToken)
            keychain.save(resp.access_token, for: KeychainManager.accessTokenKey)
            keychain.save(resp.refresh_token, for: KeychainManager.refreshTokenKey)

            let user = try await api.getMe()
            keychain.save(user.id, for: KeychainManager.userIdKey)

            isAuthed = true
            currentUserId = user.id
            backendUser = user
            authErrorMessage = nil
            loadMyProfile(modelContext: modelContext)
            return resp.is_new_user
        } catch {
            logger.error("socialLogin failed: \(error)")
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    func fetchBackendUser() async {
        guard isAuthed else { return }
        do {
            backendUser = try await api.getMe()
        } catch {
            logger.error("fetchBackendUser failed: \(error)")
        }
    }

    // MARK: - Email Auth (Backend)

    /// Email + şifre ile giriş yapar.
    /// Caller bir Task içinde `await` ile çağırmalıdır.
    func signIn(email: String, password: String, modelContext: ModelContext) async {
        accountNotFound = false
        authErrorMessage = nil
        do {
            let resp = try await api.emailLogin(email: email, password: password)
            try await saveTokensAndLoad(resp: resp, modelContext: modelContext)
        } catch let error as APIError {
            if case .httpError(404, _) = error {
                accountNotFound = true
            } else {
                authErrorMessage = emailAuthErrorMessage(error)
            }
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    /// Email + şifre ile yeni hesap oluşturur. İsim ilk adımda alınır.
    /// Caller awaits ve ardından onboarding endpoint'ini çağırmalıdır.
    func signUp(email: String, password: String, isim: String, modelContext: ModelContext) async throws {
        let resp = try await api.emailRegister(email: email, password: password, isim: isim)
        try await saveTokensAndLoad(resp: resp, modelContext: modelContext)
    }

    private func saveTokensAndLoad(resp: TokenResponse, modelContext: ModelContext) async throws {
        keychain.save(resp.access_token, for: KeychainManager.accessTokenKey)
        keychain.save(resp.refresh_token, for: KeychainManager.refreshTokenKey)
        let user = try await api.getMe()
        keychain.save(user.id, for: KeychainManager.userIdKey)
        isAuthed = true
        currentUserId = user.id
        backendUser = user
        authErrorMessage = nil
        loadMyProfile(modelContext: modelContext)
    }

    private func emailAuthErrorMessage(_ error: APIError) -> String {
        if case .httpError(let code, _) = error {
            switch code {
            case 401: return "E-posta veya şifre hatalı."
            case 409: return "Bu e-posta zaten kayıtlı."
            default: return "Sunucu hatası (\(code))"
            }
        }
        return error.localizedDescription
    }

    func signOut() {
        keychain.clearAll()
        isAuthed = false
        currentUserId = nil
        currentProfile = nil
        backendUser = nil
        authErrorMessage = nil
        accountNotFound = false
        onboardingSkipped = false
        socialLoginName = ""
    }

    // MARK: - Profile Loading

    /// Kendi profilini SwiftData'dan yükler (ownerUserId == currentUserId)
    func loadMyProfile(modelContext: ModelContext) {
        guard let uid = currentUserId else {
            currentProfile = nil
            return
        }

        let all = (try? modelContext.fetch(FetchDescriptor<Profile>())) ?? []
        currentProfile = all.first(where: { $0.ownerUserId == uid })
    }

    /// Yeni bir profil oluşturulduğunda oturumu güncellemek için kullanılır.
    func setCurrentProfile(_ profile: Profile) {
        currentProfile = profile
    }

    // MARK: - Helpers

    private func normalizeUserId(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @objc private func handleUnauthorizedNotification() {
        signOut()
    }
}
