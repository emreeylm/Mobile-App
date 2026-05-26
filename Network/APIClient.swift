import Foundation
import UIKit
import os

// MARK: - Config
//
// Öncelik sırası:
//   1. Info.plist → BINGE_DATE_API_URL   (Xcode Build Settings'ten $(BINGE_DATE_API_URL) ile gelir)
//   2. DEBUG + Simulator                 → localhost:8000
//   3. DEBUG + Gerçek cihaz             → Mac'in yerel IP'si (aşağıda güncelle)
//   4. Release + BINGE_DATE_API_URL boş → fatalError (Render URL zorunlu)
//
// Render URL'sini Xcode'a eklemek için:
//   Target → Build Settings → User-Defined → BINGE_DATE_API_URL
//   Debug:   (boş bırak, fallback devreye girer)
//   Release: https://bingedate-backend.onrender.com

private let baseURLString: String = {
    if let url = Bundle.main.infoDictionary?["BINGE_DATE_API_URL"] as? String, !url.isEmpty {
        return url
    }
    #if DEBUG
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        // Gerçek cihaz: Mac'in yerel ağ IP'si (aynı WiFi'de olmalı)
        // `ipconfig getifaddr en0` ile güncel IP'yi öğren
        return "http://192.168.1.217:8000"
        #endif
    #else
    fatalError("BINGE_DATE_API_URL tanımlanmamış. Xcode Build Settings'e Render URL'sini ekle.")
    #endif
}()

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case httpError(Int, Data)
    case decodingError(Error)
    case noNetwork

    var errorDescription: String? {
        switch self {
        case .unauthorized:     return "Oturum süresi doldu. Lütfen tekrar giriş yapın."
        case .httpError(let c, _): return "Sunucu hatası (\(c))"
        case .decodingError:    return "Veri okuma hatası"
        default:                return "Bağlantı hatası"
        }
    }
}

// MARK: - APIClient
final class APIClient {
    static let shared = APIClient()
    private init() {}

    /// HTTP → WS, HTTPS → WSS dönüşümü yapar.
    var webSocketBaseURL: String {
        baseURLString
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
    }

    private let session = URLSession.shared
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.bingedate", category: "APIClient")
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<String, Error>] = []

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true,
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await rawRequest(method, path: path, body: body, queryItems: queryItems, requiresAuth: requiresAuth)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Decoding error for \(path): \(error)")
            throw APIError.decodingError(error)
        }
    }

    @discardableResult
    func requestEmpty(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        return try await rawRequest(method, path: path, body: body, requiresAuth: requiresAuth)
    }

    // MARK: - Core

    private func rawRequest(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        var urlComponents = URLComponents(string: baseURLString + path)
        urlComponents?.queryItems = queryItems
        guard let url = urlComponents?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = keychain.load(for: KeychainManager.accessTokenKey) else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.noNetwork }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            // Token süresi dolmuş → refresh et ve tekrar dene
            do {
                let newToken = try await refreshAccessToken()
                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: request)
                guard let retryHTTP = retryResponse as? HTTPURLResponse, (200...299).contains(retryHTTP.statusCode) else {
                    NotificationCenter.default.post(name: NSNotification.Name("unauthorizedAPIResponse"), object: nil)
                    throw APIError.unauthorized
                }
                return retryData
            } catch {
                NotificationCenter.default.post(name: NSNotification.Name("unauthorizedAPIResponse"), object: nil)
                throw error
            }
        default:
            throw APIError.httpError(httpResponse.statusCode, data)
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws -> String {
        // Aynı anda birden fazla 401 gelirse sadece bir kez refresh yapar
        if isRefreshing {
            return try await withCheckedThrowingContinuation { cont in
                refreshContinuations.append(cont)
            }
        }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = keychain.load(for: KeychainManager.refreshTokenKey) else {
            throw APIError.unauthorized
        }

        let tokenResponse: TokenResponse = try await request(
            "POST",
            path: "/api/v1/auth/refresh",
            body: RefreshRequest(refresh_token: refreshToken),
            requiresAuth: false
        )

        keychain.save(tokenResponse.access_token, for: KeychainManager.accessTokenKey)
        keychain.save(tokenResponse.refresh_token, for: KeychainManager.refreshTokenKey)

        let newToken = tokenResponse.access_token
        refreshContinuations.forEach { $0.resume(returning: newToken) }
        refreshContinuations.removeAll()
        return newToken
    }
}

// MARK: - Convenience Extensions

extension APIClient {

    // Auth
    func socialLogin(provider: String, idToken: String) async throws -> TokenResponse {
        try await request("POST", path: "/api/v1/auth/social",
                          body: SocialAuthRequest(provider: provider, id_token: idToken),
                          requiresAuth: false)
    }

    func checkEmail(_ email: String) async throws -> CheckEmailResponse {
        try await request("GET", path: "/api/v1/auth/check-email",
                          queryItems: [URLQueryItem(name: "email", value: email)],
                          requiresAuth: false)
    }

    func emailRegister(email: String, password: String, isim: String) async throws -> TokenResponse {
        try await request("POST", path: "/api/v1/auth/register",
                          body: EmailRegisterRequest(email: email, password: password, isim: isim),
                          requiresAuth: false)
    }

    func emailLogin(email: String, password: String) async throws -> TokenResponse {
        try await request("POST", path: "/api/v1/auth/login",
                          body: EmailLoginRequest(email: email, password: password),
                          requiresAuth: false)
    }

    // User
    func getMe() async throws -> UserResponse {
        try await request("GET", path: "/api/v1/users/me")
    }

    func updateMe(_ body: UpdateUserRequest) async throws -> UserResponse {
        try await request("PATCH", path: "/api/v1/users/me", body: body)
    }

    // Onboarding
    func saveOnboarding(_ body: OnboardingRequest) async throws {
        try await requestEmpty("POST", path: "/api/v1/onboarding", body: body)
    }

    // Discover
    func getDiscover(
        lat: Double,
        lon: Double,
        globalMod: Bool = false,
        minAge: Int? = nil,
        maxAge: Int? = nil,
        maxDistanceKm: Int? = nil
    ) async throws -> DiscoverResponse {
        var items = [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lon", value: "\(lon)"),
            URLQueryItem(name: "global_mod", value: globalMod ? "true" : "false"),
        ]
        if let minAge { items.append(URLQueryItem(name: "min_age", value: "\(minAge)")) }
        if let maxAge { items.append(URLQueryItem(name: "max_age", value: "\(maxAge)")) }
        if let maxDistanceKm { items.append(URLQueryItem(name: "max_distance_km", value: "\(maxDistanceKm)")) }
        return try await request("GET", path: "/api/v1/discover", queryItems: items)
    }

    // Swipes
    func swipe(targetId: String, direction: String) async throws -> SwipeResponse {
        try await request("POST", path: "/api/v1/swipes",
                          body: SwipeRequest(hedef_id: targetId, yon: direction))
    }

    // Likes
    func getLikes() async throws -> LikesResponse {
        try await request("GET", path: "/api/v1/likes")
    }

    // Matches
    func getMatches() async throws -> MatchesResponse {
        try await request("GET", path: "/api/v1/matches")
    }

    // VIP
    func sendVipTicket(toId: String, message: String?) async throws -> VipResponse {
        try await request("POST", path: "/api/v1/vip/send",
                          body: VipSendRequest(alici_id: toId, mesaj: message))
    }

    func getVipBalance() async throws -> VipBalanceResponse {
        try await request("GET", path: "/api/v1/vip/balance")
    }

    // Ad Reward
    func adReward() async throws -> AdRewardResponse {
        try await request("POST", path: "/api/v1/ad/reward")
    }

    // Boost
    func activateBoost() async throws -> BoostStatusResponse {
        try await request("POST", path: "/api/v1/boost")
    }

    func getBoostStatus() async throws -> BoostStatusResponse {
        try await request("GET", path: "/api/v1/boost/status")
    }

    // Block / Report
    func blockUser(targetId: String) async throws {
        try await requestEmpty("POST", path: "/api/v1/reports/block",
                               body: BlockRequest(hedef_id: targetId))
    }

    func reportUser(targetId: String, reason: String, description: String? = nil) async throws {
        try await requestEmpty("POST", path: "/api/v1/reports/report",
                               body: ReportRequest(hedef_id: targetId, sebep: reason, aciklama: description))
    }

    // Chat History (HTTP fallback — WebSocket da son 50 mesajı gönderir)
    func getChatHistory(otherUserId: String, beforeId: Int? = nil, limit: Int = 50) async throws -> ChatHistoryResponse {
        var items = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let beforeId { items.append(URLQueryItem(name: "before_id", value: "\(beforeId)")) }
        return try await request("GET", path: "/api/v1/chat/\(otherUserId)/messages", queryItems: items)
    }

    // Device Token
    func registerDeviceToken(_ token: String) async throws {
        try await requestEmpty("POST", path: "/api/v1/notifications/device-token",
                               body: DeviceTokenRequest(token: token))
    }

    // Photo Upload
    func uploadPhoto(data: Data, mimeType: String = "image/jpeg") async throws -> PhotoUploadResponse {
        guard let url = URL(string: baseURLString + "/api/v1/users/me/photos") else {
            throw APIError.invalidURL
        }
        guard let token = keychain.load(for: KeychainManager.accessTokenKey) else {
            throw APIError.unauthorized
        }

        // Yükleme öncesi sıkıştır (1000px max, %75 JPEG kalitesi)
        let uploadData = compressForUpload(data) ?? data

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(uploadData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (respData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, respData)
        }
        return try JSONDecoder().decode(PhotoUploadResponse.self, from: respData)
    }

    /// Fotoğrafı 1000px max boyuta indirger ve %75 JPEG sıkıştırması uygular.
    /// 5 MB üzerindeyse mutlaka sıkıştırır; altındaysa yine de kalite ayarı yapılır.
    private func compressForUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1000
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
