import Foundation
import os

struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String? // for TV shows
    let poster_path: String?
    let backdrop_path: String?
    let overview: String?
    let release_date: String?
    let first_air_date: String?
    
    var displayName: String {
        title ?? name ?? "Unknown"
    }
    
    var mediaType: MediaType {
        title != nil ? .movie : .series
    }
    
    var posterURL: String? {
        if let path = poster_path {
            return "https://image.tmdb.org/t/p/w342\(path)"
        }
        if let bPath = backdrop_path {
            return "https://image.tmdb.org/t/p/w342\(bPath)"
        }
        return nil
    }
}

struct TMDBResponse: Codable {
    let results: [TMDBSearchResult]
}

class TMDBService {
    static let shared = TMDBService()
    private let logger = Logger(subsystem: "com.bingedate", category: "TMDBService")

    /// API key'i Info.plist'ten okur.
    /// Xcode scheme / .xcconfig → `TMDB_API_KEY=<key>` ile tanımlanmalı,
    /// Info.plist'e `<key>TMDB_API_KEY</key><string>$(TMDB_API_KEY)</string>` eklenmelidir.
    private let apiKey: String = {
        if let key = Bundle.main.infoDictionary?["TMDB_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        // Fallback: hardcode (geliştirme ortamı için; üretimde Info.plist kullanın)
        return "b4ff215cd5e7eb31939788e97cac1488"
    }()

    private let baseURL = "https://api.themoviedb.org/3"
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    
    func search(query: String, type: MediaType) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        let endpoint = type == .movie ? "/search/movie" : "/search/tv"
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: "tr-TR"),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                logger.warning("TMDB API error: status \(httpResponse.statusCode)")
                return getMockData(type: type).filter { $0.displayName.localizedCaseInsensitiveContains(query) }
            }
            let res = try decoder.decode(TMDBResponse.self, from: data)
            return res.results
        } catch {
            logger.error("TMDB API fetch failed: \(error)")
            return getMockData(type: type).filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
    }
    
    /// Film ve dizi aramasını paralel çalıştırır, sonuçları birleştirir.
    func searchAll(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        async let movies = search(query: query, type: .movie)
        async let series = search(query: query, type: .series)
        let (m, s) = try await (movies, series)
        // Önce diziler, sonra filmler; toplamda 6 sonuç
        return Array((s + m).prefix(6))
    }

    func fetchPopular(type: MediaType) async throws -> [TMDBSearchResult] {
        let endpoint = type == .movie ? "/movie/popular" : "/tv/popular"
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "tr-TR"),
            URLQueryItem(name: "page", value: "1")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                logger.warning("TMDB API error: status \(httpResponse.statusCode)")
                return getMockData(type: type)
            }
            let res = try decoder.decode(TMDBResponse.self, from: data)
            return res.results
        } catch {
            logger.error("TMDB API fetch failed: \(error)")
            return getMockData(type: type)
        }
    }

    private func getMockData(type: MediaType) -> [TMDBSearchResult] {
        if type == .movie {
            return [
                TMDBSearchResult(id: 1, title: "Inception", name: nil, poster_path: "/oYuS63B346U0jIun7VatWAt470Y.jpg", backdrop_path: nil, overview: "A thief who steals corporate secrets through the use of dream-sharing technology...", release_date: "2010", first_air_date: nil),
                TMDBSearchResult(id: 2, title: "Interstellar", name: nil, poster_path: "/gEU2QniE6E77NI6vCU67oYvD0An.jpg", backdrop_path: nil, overview: "The adventures of a group of explorers who make use of a newly discovered wormhole...", release_date: "2014", first_air_date: nil),
                TMDBSearchResult(id: 3, title: "The Dark Knight", name: nil, poster_path: "/qJ2tW6WMUDp9s1vmsTu4X3q7SCD.jpg", backdrop_path: nil, overview: "Batman raises the stakes in his war on crime...", release_date: "2008", first_air_date: nil),
                TMDBSearchResult(id: 4, title: "The Matrix", name: nil, poster_path: "/f89U3YUn30sbmXLpYp9zSTC5pXn.jpg", backdrop_path: nil, overview: "A computer hacker learns from mysterious rebels about the true nature of his reality...", release_date: "1999", first_air_date: nil),
                TMDBSearchResult(id: 5, title: "Pulp Fiction", name: nil, poster_path: "/d5iIl9h9FvSbi9snRlgGNc7jSjF.jpg", backdrop_path: nil, overview: "The lives of two mob hitmen, a boxer, a gangster and his wife...", release_date: "1994", first_air_date: nil)
            ]
        } else {
            return [
                TMDBSearchResult(id: 101, title: nil, name: "Breaking Bad", poster_path: "/ggFHnqyc0nJMf979ojYpkBio06v.jpg", backdrop_path: nil, overview: "A high school chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine...", release_date: nil, first_air_date: "2008"),
                TMDBSearchResult(id: 102, title: nil, name: "Stranger Things", poster_path: "/x2LSRm21uTExHi0btREvP07mU09.jpg", backdrop_path: nil, overview: "When a young boy vanishes, a small town uncovers a mystery involving secret experiments...", release_date: nil, first_air_date: "2016"),
                TMDBSearchResult(id: 103, title: nil, name: "Dark", poster_path: "/apbr78Csl198S9Wp97kz9m9MEpU.jpg", backdrop_path: nil, overview: "A family saga with a supernatural twist, set in a German town, where the disappearance of two young children exposes the relationships among four families...", release_date: nil, first_air_date: "2017"),
                TMDBSearchResult(id: 104, title: nil, name: "The Office", poster_path: "/7D6i9S8u38v8u54VjST06b5iH47.jpg", backdrop_path: nil, overview: "The everyday lives of office employees in the Scranton, Pennsylvania branch of the fictional Dunder Mifflin Paper Company...", release_date: nil, first_air_date: "2005"),
                TMDBSearchResult(id: 105, title: nil, name: "Friends", poster_path: "/f496p9xyv7GBr7AJvzw77Y6p3rV.jpg", backdrop_path: nil, overview: "Follows the personal and professional lives of six twenty to thirty-something-year-old friends living in Manhattan...", release_date: nil, first_air_date: "1994")
            ]
        }
    }
}
