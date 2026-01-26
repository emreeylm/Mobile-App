import Foundation
import SwiftData
import Combine

@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Auth State

    @Published var isAuthed: Bool = false
    @Published var currentUserId: String? = nil

    // MARK: - Profile State

    @Published var currentProfile: Profile? = nil

    // MARK: - UI State (opsiyonel)

    @Published var authErrorMessage: String? = nil

    private let userDefaultsKey = "currentUserId"

    // MARK: - Bootstrap

    /// App açılınca çağrılır: login var mı bakar, varsa profili çeker
    func bootstrap(modelContext: ModelContext) {
        if let uid = UserDefaults.standard.string(forKey: userDefaultsKey),
           uid.isEmpty == false {
            isAuthed = true
            currentUserId = uid
            loadMyProfile(modelContext: modelContext)
        } else {
            isAuthed = false
            currentUserId = nil
            currentProfile = nil
        }
    }

    // MARK: - Auth Actions (Demo)

    /// Demo giriş: email'i userId gibi kullanır.
    func signIn(email: String, password: String, modelContext: ModelContext) {
        let uid = normalizeUserId(email)
        UserDefaults.standard.set(uid, forKey: userDefaultsKey)

        isAuthed = true
        currentUserId = uid
        authErrorMessage = nil

        loadMyProfile(modelContext: modelContext)
    }

    /// Demo kayıt: userId kaydeder, profil SignUpFlowView içinde oluşturulur.
    func signUp(email: String, password: String, modelContext: ModelContext) {
        let uid = normalizeUserId(email)
        UserDefaults.standard.set(uid, forKey: userDefaultsKey)

        isAuthed = true
        currentUserId = uid
        authErrorMessage = nil

        // ✅ Profil SignUpFlowView akışı içinde oluşturulacak.
        currentProfile = nil
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        isAuthed = false
        currentUserId = nil
        currentProfile = nil
        authErrorMessage = nil
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
}
