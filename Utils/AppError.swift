import Foundation

enum AppError: LocalizedError {
    case invalidCredentials
    case emailAlreadyUsed
    case userNotFound
    case weakPassword
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "E-posta veya şifre hatalı."
        case .emailAlreadyUsed:   return "Bu e-posta zaten kullanılıyor."
        case .userNotFound:       return "Kullanıcı bulunamadı."
        case .weakPassword:       return "Şifre en az 6 karakter olmalı."
        case .unknown(let msg):   return msg
        }
    }
}
