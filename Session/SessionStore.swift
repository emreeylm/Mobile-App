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

    // MARK: - UI State

    @Published var authErrorMessage: String? = nil

    private let keychain = KeychainManager.shared
    private let api = APIClient.shared
    private let logger = Logger(subsystem: "com.bingedate", category: "SessionStore")

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUnauthorizedNotification), name: NSNotification.Name("unauthorizedAPIResponse"), object: nil)
    }

    // MARK: - Bootstrap

    /// App açılınca çağrılır: Keychain'e bakar, token varsa sessiz giriş yapar
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

    // MARK: - Social Auth (Apple / Google)

    /// Apple veya Google id_token ile backend'e giriş yapar.
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

    /// Hesabı backend'de kalıcı olarak siler, ardından oturumu kapatır.
    func deleteAccount(modelContext: ModelContext) async {
        do {
            try await api.deleteAccount()
        } catch {
            logger.error("deleteAccount API hatası: \(error) — yine de yerel oturum kapatılıyor")
        }
        try? modelContext.delete(model: Profile.self)
        try? modelContext.save()
        signOut()
    }

    func signOut() {
        keychain.clearAll()
        isAuthed = false
        currentUserId = nil
        currentProfile = nil
        backendUser = nil
        authErrorMessage = nil
        onboardingSkipped = false
        socialLoginName = ""
    }

    // MARK: - Profile Loading

    func loadMyProfile(modelContext: ModelContext) {
        guard let uid = currentUserId else {
            currentProfile = nil
            return
        }
        let all = (try? modelContext.fetch(FetchDescriptor<Profile>())) ?? []
        currentProfile = all.first(where: { $0.ownerUserId == uid })
    }

    func setCurrentProfile(_ profile: Profile) {
        currentProfile = profile
    }

    // MARK: - Helpers

    @objc private func handleUnauthorizedNotification() {
        signOut()
    }
}
