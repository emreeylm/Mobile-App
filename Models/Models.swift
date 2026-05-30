import Foundation
import SwiftData

// MARK: - Enums

enum MediaType: String, Codable, CaseIterable {
    case movie = "Movie"
    case series = "Series"
}

enum Gender: String, Codable, CaseIterable {
    case male = "Erkek"
    case female = "Kadın"
    case other = "Diğer"
}

enum LookingForGender: String, Codable, CaseIterable {
    case male = "Erkek"
    case female = "Kadın"
    case everyone = "Herkes"
}

// MARK: - Models

@Model
final class Profile {
    @Attribute(.unique) var id: String
    var ownerUserId: String

    var firstName: String
    var lastName: String
    var age: Int
    var city: String
    var jobTitle: String
    var bio: String

    var genderRaw: String
    var lookingForGenderRaw: String

    var avatarSymbol: String
    var favoriteMovieGenres: [String]
    
    // New fields
    var birthday: Date?
    var height: String = "170 cm"
    var showHeight: Bool = true
    var smokingHabit: String = "Söylemek istemiyorum"
    var alcoholHabit: String = "Söylemek istemiyorum"
    var interests: [String] = []
    var nowWatching: String = ""

    /// Backend'den gelen profil fotoğrafı URL'si (S3 veya TMDB poster).
    /// Yerel fotoğraf varsa bu alan görmezden gelinir.
    var remotePhotoURL: String? = nil

    @Relationship(deleteRule: .cascade) var photos: [ProfilePhoto] = []
    
    // ✅ Access to selected media via ProfileMedia
    @Relationship(deleteRule: .cascade, inverse: \ProfileMedia.profile) 
    var mediaLinks: [ProfileMedia] = []

    init(
        ownerUserId: String,
        firstName: String,
        lastName: String,
        city: String = "",
        jobTitle: String = "Belirtilmedi",
        bio: String,
        gender: Gender = .other,
        lookingForGender: LookingForGender = .everyone,
        avatarSymbol: String = "person.fill",
        favoriteMovieGenres: [String] = [],
        birthday: Date? = nil,
        height: String = "170 cm",
        smokingHabit: String = "Söylemek istemiyorum",
        alcoholHabit: String = "Söylemek istemiyorum",
        interests: [String] = [],
        nowWatching: String = "",
        remotePhotoURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.ownerUserId = ownerUserId
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.jobTitle = jobTitle
        self.bio = bio
        self.genderRaw = gender.rawValue
        self.lookingForGenderRaw = lookingForGender.rawValue
        self.avatarSymbol = avatarSymbol
        self.favoriteMovieGenres = favoriteMovieGenres
        self.birthday = birthday
        self.height = height
        self.smokingHabit = smokingHabit
        self.alcoholHabit = alcoholHabit
        self.interests = interests
        self.nowWatching = nowWatching
        self.remotePhotoURL = remotePhotoURL

        // Calculate age once at init
        if let bday = birthday {
            self.age = Calendar.current.dateComponents([.year], from: bday, to: .now).year ?? 18
        } else {
            self.age = 18
        }
    }

    var calculatedAge: Int {
        guard let birthday = birthday else { return 18 }
        return Calendar.current.dateComponents([.year], from: birthday, to: .now).year ?? 18
    }

    var name: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .other }
        set { genderRaw = newValue.rawValue }
    }

    var lookingForGender: LookingForGender {
        get { LookingForGender(rawValue: lookingForGenderRaw) ?? .everyone }
        set { lookingForGenderRaw = newValue.rawValue }
    }
}

@Model
final class ProfilePhoto {
    @Attribute(.unique) var id: String
    var data: Data
    var order: Int

    init(data: Data, order: Int) {
        self.id = UUID().uuidString
        self.data = data
        self.order = order
    }
}

@Model
final class MediaItem {
    @Attribute(.unique) var id: String
    var tmdbId: Int?
    var title: String
    var typeRaw: String
    var coverImage: String? // SF Symbol or URL string
    var posterPath: String?
    var backdropPath: String?
    
    // ✅ DiscoverView sıralaması için
    var createdAt: Date

    init(title: String, type: MediaType, coverImage: String? = nil, tmdbId: Int? = nil, posterPath: String? = nil, backdropPath: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.typeRaw = type.rawValue
        self.coverImage = coverImage
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.createdAt = .now
    }

    var type: MediaType {
        get { MediaType(rawValue: typeRaw) ?? .movie }
        set { typeRaw = newValue.rawValue }
    }

    var posterSymbol: String {
        type == .movie ? "film" : "tv"
    }
    
    var posterURL: String? {
        if let path = posterPath {
            return "https://image.tmdb.org/t/p/w342\(path)"
        }
        if let bPath = backdropPath {
            return "https://image.tmdb.org/t/p/w342\(bPath)"
        }
        return nil
    }
}

@Model
final class ProfileMedia {
    @Attribute(.unique) var id: String
    var profileId: String
    var mediaId: String
    
    // ✅ Add Relationship for inverse reference
    var profile: Profile?
    
    // Also add media relationship for easier access? 
    // Let's add it to support `link.media` usage nicely
    @Relationship var media: MediaItem?

    init(profileId: String, mediaId: String) {
        self.id = UUID().uuidString
        self.profileId = profileId
        self.mediaId = mediaId
    }
}

@Model
final class LikeEdge {
    @Attribute(.unique) var id: String
    var fromProfileId: String
    var toProfileId: String
    var isLike: Bool
    var isSuperLike: Bool
    var createdAt: Date

    init(fromProfileId: String, toProfileId: String, isLike: Bool, isSuperLike: Bool = false) {
        self.id = UUID().uuidString
        self.fromProfileId = fromProfileId
        self.toProfileId = toProfileId
        self.isLike = isLike
        self.isSuperLike = isSuperLike
        self.createdAt = .now
    }
}

@Model
final class Match {
    @Attribute(.unique) var id: String
    var myProfileId: String
    var otherProfileId: String
    var createdAt: Date

    init(myProfileId: String, otherProfileId: String) {
        self.id = UUID().uuidString
        self.myProfileId = myProfileId
        self.otherProfileId = otherProfileId
        self.createdAt = .now
    }
}

@Model
final class ChatThread {
    @Attribute(.unique) var id: String
    var myProfileId: String
    var otherProfileId: String
    var updatedAt: Date

    init(myProfileId: String, otherProfileId: String) {
        self.id = UUID().uuidString
        self.myProfileId = myProfileId
        self.otherProfileId = otherProfileId
        self.updatedAt = .now
    }
}

@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: String
    var threadId: String
    var senderProfileId: String
    var text: String
    var imageData: Data?
    var createdAt: Date
    var isRead: Bool
    /// Backend'den gelen mesaj ID'si (String). "" = sadece yerel mesaj.
    var remoteIdStr: String = ""

    init(
        threadId: String,
        senderProfileId: String,
        text: String = "",
        imageData: Data? = nil,
        isRead: Bool = false
    ) {
        self.id = UUID().uuidString
        self.threadId = threadId
        self.senderProfileId = senderProfileId
        self.text = text
        self.imageData = imageData
        self.createdAt = .now
        self.isRead = isRead
        self.remoteIdStr = ""
    }
}
