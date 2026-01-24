import SwiftData
import Foundation

struct DemoSeeder {

    static func seedIfNeeded(context: ModelContext) {

        let descriptor = FetchDescriptor<Profile>()
        let existing = (try? context.fetch(descriptor)) ?? []

        // Daha önce seed edildiyse çık
        if existing.isEmpty == false { return }

        // MARK: - Demo Profiller

        let profiles: [Profile] = [

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Ahmet",
                lastName: "Yılmaz",
                age: 26,
                city: "İstanbul",
                jobTitle: "Yazılım Geliştirici",
                bio: "Film ve dizilere bayılırım. Kahve + sinema ❤️",
                gender: .male,
                lookingForGender: .female,
                favoriteMovieGenres: ["Dram", "Bilim Kurgu", "Gerilim"]
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Elif",
                lastName: "Demir",
                age: 24,
                city: "Ankara",
                jobTitle: "Psikolog",
                bio: "Sanat filmleri ve mini diziler favorim 🎬",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Dram", "Romantik", "Gizem"]
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Mert",
                lastName: "Kaya",
                age: 28,
                city: "İzmir",
                jobTitle: "Ürün Yöneticisi",
                bio: "IMDB listeleri yapmayı severim 😄",
                gender: .male,
                lookingForGender: .female,
                favoriteMovieGenres: ["Aksiyon", "Suç", "Gerilim"]
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Zeynep",
                lastName: "Arslan",
                age: 25,
                city: "Bursa",
                jobTitle: "Grafik Tasarımcı",
                bio: "Karanlık diziler ve estetik filmler ✨",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Fantastik", "Gizem", "Korku"]
            )
        ]

        // MARK: - Insert Profiller
        for profile in profiles {
            context.insert(profile)
        }
        
        // MARK: - Demo Medya ve İlişkiler
        let movies = [
            "Inception", "The Dark Knight", "Interstellar", "Fight Club", "Pulp Fiction",
            "The Matrix", "Goodfellas", "Seven", "City of God", "The Silence of the Lambs"
        ].map { MediaItem(title: $0, type: .movie) }
        
        let series = [
            "Breaking Bad", "Game of Thrones", "Chernobyl", "The Wire", "Stranger Things",
            "Dark", "Black Mirror", "Sherlock", "True Detective", "Fargo"
        ].map { MediaItem(title: $0, type: .series) }
        
        let allMedia = movies + series
        for m in allMedia { context.insert(m) }
        
        // Link random media to profiles
        for profile in profiles {
            // Pick 3-5 random items
            let shuffled = allMedia.shuffled().prefix(Int.random(in: 3...5))
            for item in shuffled {
                let link = ProfileMedia(profileId: profile.id, mediaId: item.id)
                link.media = item // ✅ Property exists now!
                // link.profile = profile // (Implicitly handled by append usually, but can set explicit if needed)
                context.insert(link)
                profile.mediaLinks.append(link)
            }
        }

        try? context.save()
    }
}
