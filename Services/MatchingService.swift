import Foundation
import SwiftData

struct MatchingService {
    
    /// Calculates a match percentage (0-100) between two profiles.
    /// - Parameters:
    ///   - user: The current user's profile.
    ///   - candidate: The potential match's profile.
    /// - Returns: An integer score from 0 to 100.
    static func calculateMatchScore(user: Profile, candidate: Profile) -> Int {
        var score: Double = 0.0
        
        // 1. Genre Overlap (40%)
        let userGenres = Set(user.favoriteMovieGenres)
        let candidateGenres = Set(candidate.favoriteMovieGenres)
        let sharedGenres = userGenres.intersection(candidateGenres)
        
        if !userGenres.isEmpty {
            let genreRatio = Double(sharedGenres.count) / Double(userGenres.count)
            score += min(genreRatio * 40.0, 40.0)
        }
        
        // 2. Media Overlap (Movies/Series) (60%)
        let userMedia = Set(user.mediaLinks.map { $0.mediaId })
        let candidateMedia = Set(candidate.mediaLinks.map { $0.mediaId })
        let sharedMedia = userMedia.intersection(candidateMedia)
        
        // If user has no media, rely on genres. If they have media, score it.
        if !userMedia.isEmpty {
            // Assume 5 shared items is "perfect" (60 pts)
            let pointsPerItem: Double = 12.0
            let mediaScore = Double(sharedMedia.count) * pointsPerItem
            score += min(mediaScore, 60.0)
        } else {
            // User has no media? Distribute 60% to random "vibe" or genre boost
            // Or just keep it low to encourage adding media.
            if score > 20 { score += 20 }
        }
        
        return min(Int(score), 100)
    }
    
    static func getCommonSummary(user: Profile, candidate: Profile) -> String {
        let userMedia = Set(user.mediaLinks.map { $0.mediaId })
        let candidateMedia = Set(candidate.mediaLinks.map { $0.mediaId })
        let sharedMediaCount = userMedia.intersection(candidateMedia).count
        
        let userGenres = Set(user.favoriteMovieGenres)
        let candidateGenres = Set(candidate.favoriteMovieGenres)
        let sharedGenres = userGenres.intersection(candidateGenres)
        
        var components: [String] = []
        
        if sharedMediaCount > 0 {
            components.append("\(sharedMediaCount) Ortak Yapım")
        }
        
        if !sharedGenres.isEmpty {
            // Pick top 2 genres
            let genreText = sharedGenres.prefix(2).joined(separator: " & ")
            components.append(genreText)
        }
        
        if components.isEmpty {
            return "Benzer zevkler aranıyor..."
        }
        
        return components.joined(separator: " • ")
    }
}
