import Foundation

// MARK: - Auth
struct SocialAuthRequest: Encodable {
    let provider: String
    let id_token: String
}

struct EmailRegisterRequest: Encodable {
    let email: String
    let password: String
    let isim: String
}

struct EmailLoginRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refresh_token: String
}

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let is_new_user: Bool
}

// MARK: - User
struct UserResponse: Decodable {
    let id: String
    let email: String
    let isim: String
    let yas: Int
    let cinsiyet: String
    let hedef_cinsiyet: String
    let now_watching: String?
    let is_premium: Bool
    let is_admin: Bool        // Admin paneli erişimi için
    let auth_provider: String? // "email" | "apple" | "google"
}

struct UpdateUserRequest: Encodable {
    var isim: String?
    var yas: Int?
    var cinsiyet: String?
    var hedef_cinsiyet: String?
    var now_watching: String?
    var konum: KoordinatRequest?
    var is_premium: Bool?
}

struct KoordinatRequest: Encodable {
    let lat: Double
    let lon: Double
}

// MARK: - Onboarding
struct OnboardingMediaItem: Encodable {
    let id: Int
    let baslik: String
    let tip: String
    let afis_url: String?
}

struct OnboardingRequest: Encodable {
    let diziler: [OnboardingMediaItem]
    let filmler: [OnboardingMediaItem]
    let turler: [String]
}

// MARK: - Discover
struct DiscoverResponse: Decodable {
    let kullanicilar: [DiscoverUser]
}

struct DiscoverUser: Decodable {
    let id: String
    let isim: String
    let yas: Int
    let now_watching: String?
    let uyumluluk_skoru: Int
    let foto_url: String?        // Profil fotoğrafı veya TMDB poster URL'si
    let ortak_medya: [String]    // Ortak medya başlıkları (en fazla 3)
}

// MARK: - Swipe
struct SwipeRequest: Encodable {
    let hedef_id: String
    let yon: String  // "like" | "dislike"
}

struct SwipeResponse: Decodable {
    let basarili: Bool
    let eslesme_oldu: Bool
    let kalan_hak: Int?
}

// MARK: - Likes
struct LikesResponse: Decodable {
    let likes: [LikeEntry]
}

struct LikeEntry: Decodable {
    let id: String
    let yas: Int
    let tarih: String
    let blur: Bool
    let isim: String?
    let now_watching: String?
}

// MARK: - Matches
struct MatchesResponse: Decodable {
    let matches: [MatchEntry]
}

struct MatchEntry: Decodable {
    let id: String
    let isim: String
    let yas: Int
    let now_watching: String?
}

// MARK: - VIP
struct VipSendRequest: Encodable {
    let alici_id: String
    let mesaj: String?
}

struct VipResponse: Decodable {
    let basarili: Bool
    let kalan_bilet: Int
    let eslesme_oldu: Bool
}

struct VipBalanceResponse: Decodable {
    let balance: Int
}

// MARK: - Boost
struct BoostStatusResponse: Decodable {
    let active: Bool
    let remaining_seconds: Int
}

// MARK: - Ad Reward
struct AdRewardResponse: Decodable {
    let basarili: Bool
    let kalan_hak: Int
}

// MARK: - Block / Report
struct BlockRequest: Encodable {
    let hedef_id: String
}

struct ReportRequest: Encodable {
    let hedef_id: String
    let sebep: String
    let aciklama: String?
}

// MARK: - Device Token
struct DeviceTokenRequest: Encodable {
    let token: String
}

// MARK: - Photo Upload
struct PhotoUploadResponse: Decodable {
    let url: String
    let photo_id: String
}

// MARK: - Chat History
struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessageDTO]
}

struct ChatMessageDTO: Decodable {
    let id: Int
    let from: String   // backend user UUID string
    let text: String
    let tarih: String  // ISO8601
}
