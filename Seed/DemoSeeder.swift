import SwiftData
import Foundation

struct DemoSeeder {

    static func seedIfNeeded(context: ModelContext) {

        let descriptor = FetchDescriptor<Profile>()
        let existing = (try? context.fetch(descriptor)) ?? []

        // MARK: - Demo Profiller
        if existing.isEmpty {
            createInitialProfiles(context: context)
        }
        
        // Populate if no interactions exist
        let likesCount = (try? context.fetchCount(FetchDescriptor<LikeEdge>())) ?? 0
        let threadsCount = (try? context.fetchCount(FetchDescriptor<ChatThread>())) ?? 0
        
        if likesCount < 5 || threadsCount < 2 {
            populateInteractions(context: context)
        }
        
        try? context.save()
    }

    private static func createInitialProfiles(context: ModelContext) {

        let profiles: [Profile] = [

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Ahmet",
                lastName: "Yılmaz",
                city: "İstanbul",
                jobTitle: "Yazılım Geliştirici",
                bio: "Film ve dizilere bayılırım. Kahve + sinema ❤️",
                gender: .male,
                lookingForGender: .female,
                favoriteMovieGenres: ["Dram", "Bilim Kurgu", "Gerilim"],
                birthday: Calendar.current.date(byAdding: .year, value: -26, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Elif",
                lastName: "Demir",
                city: "Ankara",
                jobTitle: "Psikolog",
                bio: "Sanat filmleri ve mini diziler favorim 🎬",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Dram", "Romantik", "Gizem"],
                birthday: Calendar.current.date(byAdding: .year, value: -24, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Sarah",
                lastName: "Miller",
                city: "İstanbul",
                jobTitle: "Art Director",
                bio: "Loves indie rock and vintage movies.",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Romantik", "Dram"],
                birthday: Calendar.current.date(byAdding: .year, value: -27, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Aysu",
                lastName: "Korkmaz",
                city: "İzmir",
                jobTitle: "Student",
                bio: "K-Drama enthusiast!",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Gizem", "Fantastik"],
                birthday: Calendar.current.date(byAdding: .year, value: -23, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Jessica",
                lastName: "Jones",
                city: "İstanbul",
                jobTitle: "Chef",
                bio: "Cooking and late night movies.",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Suç", "Belgesel"],
                birthday: Calendar.current.date(byAdding: .year, value: -29, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Leyla",
                lastName: "Bak",
                city: "Ankara",
                jobTitle: "Teacher",
                bio: "Bookworm and movie lover.",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Dram", "Tarihi"],
                birthday: Calendar.current.date(byAdding: .year, value: -25, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Maya",
                lastName: "Güneş",
                city: "İstanbul",
                jobTitle: "Architect",
                bio: "Minimalism and noir films.",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Gerilim", "Korku"],
                birthday: Calendar.current.date(byAdding: .year, value: -24, to: .now)
            ),

            Profile(
                ownerUserId: UUID().uuidString,
                firstName: "Hande",
                lastName: "Ercel",
                city: "Muğla",
                jobTitle: "Model",
                bio: "Loves to travel and watch comedies.",
                gender: .female,
                lookingForGender: .male,
                favoriteMovieGenres: ["Komedi", "Macera"],
                birthday: Calendar.current.date(byAdding: .year, value: -28, to: .now)
            )
        ]

        // MARK: - Insert Profiller
        for profile in profiles {
            context.insert(profile)
        }
        
        // MARK: - Demo Medya ve İlişkiler
        let movies = [
            ("Inception", "film"), ("The Dark Knight", "film.fill"), ("Interstellar", "sparkles.tv"), 
            ("Fight Club", "fist.fill"), ("Pulp Fiction", "book.fill"), ("The Matrix", "cpu"),
            ("Goodfellas", "person.3.fill"), ("Seven", "number"), ("City of God", "house.fill"), 
            ("The Silence of the Lambs", "mouth.fill")
        ].map { MediaItem(title: $0.0, type: .movie, coverImage: $0.1) }
        
        let series = [
            ("Breaking Bad", "flask.fill"), ("Game of Thrones", "crown.fill"), ("Chernobyl", "pills.fill"), 
            ("The Wire", "phone.fill"), ("Stranger Things", "bolt.fill"), ("Dark", "clock.fill"), 
            ("Black Mirror", "video.slash.fill"), ("Sherlock", "magnifyingglass"), ("True Detective", "eye.fill"), 
            ("Fargo", "snow")
        ].map { MediaItem(title: $0.0, type: .series, coverImage: $0.1) }
        
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
    
    public static func populateInteractions(context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
        guard profiles.count >= 2 else { return }
        
        let existingLikes = (try? context.fetch(FetchDescriptor<LikeEdge>())) ?? []
        let existingThreads = (try? context.fetch(FetchDescriptor<ChatThread>())) ?? []
        
        // Let's create interactions for everyone so any profile logged in feels "busy"
        for me in profiles {
            let others = profiles.filter { $0.id != me.id }.shuffled()
            
            // 1. Incoming Likes (to 'me') - 2 random profiles
            for sender in others.prefix(2) {
                if !existingLikes.contains(where: { $0.fromProfileId == sender.id && $0.toProfileId == me.id }) {
                    let like = LikeEdge(fromProfileId: sender.id, toProfileId: me.id, isLike: true, isSuperLike: false)
                    context.insert(like)
                }
            }
            
            // 2. Incoming SuperLikes (to 'me') - 1 random profile
            if others.count > 2 {
                let sender = others[2]
                if !existingLikes.contains(where: { $0.fromProfileId == sender.id && $0.toProfileId == me.id }) {
                    let superLike = LikeEdge(fromProfileId: sender.id, toProfileId: me.id, isLike: true, isSuperLike: true)
                    context.insert(superLike)
                }
            }
            
            // 3. Matches & Message Threads - 2 random profiles
            if others.count > 4 {
                for other in others.suffix(2) {
                    // Check if thread exists
                    let threadExists = existingThreads.contains(where: { 
                        ($0.myProfileId == me.id && $0.otherProfileId == other.id) ||
                        ($0.myProfileId == other.id && $0.otherProfileId == me.id)
                    })
                    
                    if !threadExists {
                        // Create Match
                        let match = Match(myProfileId: me.id, otherProfileId: other.id)
                        context.insert(match)
                        
                        // Create Chat Thread
                        let thread = ChatThread(myProfileId: me.id, otherProfileId: other.id)
                        context.insert(thread)
                        
                        // Create initial messages
                        let messages = [
                            "Selam! Profilini çok beğendim.",
                            "Teşekkürler! Senin zevklerin de harika görünüyor.",
                            "En son hangi filmi izledin?",
                            "Tenet'i izledim, inanılmazdı!",
                            "Kesinlikle, Christopher Nolan bir dahi."
                        ]
                        
                        for (index, text) in messages.enumerated() {
                            let senderId = index % 2 == 0 ? other.id : me.id
                            let msg = ChatMessage(threadId: thread.id, senderProfileId: senderId, text: text)
                            msg.createdAt = Date().addingTimeInterval(TimeInterval(-3600 * (messages.count - index)))
                            context.insert(msg)
                        }
                        
                        thread.updatedAt = .now
                    }
                }
            }
        }
        try? context.save()
    }
}
