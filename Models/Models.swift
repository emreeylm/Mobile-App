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
    
    // New fields for the redesigned profile
    var height: String = "175 cm"
    var zodiac: String = "Aslan"
    var smokingHabit: String = "İçmiyor"

    @Relationship(deleteRule: .cascade) var photos: [ProfilePhoto] = []
    
    // ✅ Access to selected media via ProfileMedia
    @Relationship(deleteRule: .cascade, inverse: \ProfileMedia.profile) 
    var mediaLinks: [ProfileMedia] = []

    init(
        ownerUserId: String,
        firstName: String,
        lastName: String,
        age: Int,
        city: String,
        jobTitle: String,
        bio: String,
        gender: Gender = .other,
        lookingForGender: LookingForGender = .everyone,
        avatarSymbol: String = "person.fill",
        favoriteMovieGenres: [String] = [],
        height: String = "175 cm",
        zodiac: String = "Aslan",
        smokingHabit: String = "İçmiyor"
    ) {
        self.id = UUID().uuidString
        self.ownerUserId = ownerUserId
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.city = city
        self.jobTitle = jobTitle
        self.bio = bio
        self.genderRaw = gender.rawValue
        self.lookingForGenderRaw = lookingForGender.rawValue
        self.avatarSymbol = avatarSymbol
        self.favoriteMovieGenres = favoriteMovieGenres
        self.height = height
        self.zodiac = zodiac
        self.smokingHabit = smokingHabit
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
    var title: String
    var typeRaw: String

    // ✅ DiscoverView sıralaması için
    var createdAt: Date

    init(title: String, type: MediaType) {
        self.id = UUID().uuidString
        self.title = title
        self.typeRaw = type.rawValue
        self.createdAt = .now
    }

    var type: MediaType {
        get { MediaType(rawValue: typeRaw) ?? .movie }
        set { typeRaw = newValue.rawValue }
    }

    var posterSymbol: String {
        type == .movie ? "film" : "tv"
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
    var createdAt: Date

    init(fromProfileId: String, toProfileId: String, isLike: Bool) {
        self.id = UUID().uuidString
        self.fromProfileId = fromProfileId
        self.toProfileId = toProfileId
        self.isLike = isLike
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
final class ChatMessage {
    @Attribute(.unique) var id: String
    var threadId: String
    var senderProfileId: String
    var text: String
    var createdAt: Date
    var isRead: Bool

    init(threadId: String, senderProfileId: String, text: String, isRead: Bool = false) {
        self.id = UUID().uuidString
        self.threadId = threadId
        self.senderProfileId = senderProfileId
        self.text = text
        self.createdAt = .now
        self.isRead = isRead
    }
}
