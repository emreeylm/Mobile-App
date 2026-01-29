import SwiftUI
import SwiftData

struct DiscoverView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @Query private var mediaItems: [MediaItem]
    @Query private var profileMedia: [ProfileMedia]

    @State private var filterType: String = "Popüler" // Popüler, Filmler, Diziler
    @State private var search: String = ""
    @State private var apiResults: [TMDBSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isInitialLoad = true

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        searchBar
                        filterChips
                        mediaGrid
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 100) // Tab bar clearance
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarHidden(true)
        .onAppear { 
            if isInitialLoad {
                Task { await fetchInitialMedia() }
                isInitialLoad = false
            }
        }
        .onChange(of: search) { _, newValue in
            searchMedia(query: newValue)
        }
        .onChange(of: filterType) { _, _ in
            if search.isEmpty {
                Task { await fetchInitialMedia() }
            } else {
                searchMedia(query: search)
            }
        }
    }

    // MARK: - Header UI

    private var headerView: some View {
        HStack {
            Spacer()
            
            Text("Keşfet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.text)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    // MARK: - Search Bar UI

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.text.opacity(0.4))
            
            TextField("Film veya dizi ara...", text: $search)
                .foregroundColor(AppTheme.text)
                .tint(AppTheme.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(AppTheme.text.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppTheme.text.opacity(0.15), lineWidth: 1.5)
        )
    }

    // MARK: - Filter Chips UI

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(title: "Popüler")
                filterChip(title: "Filmler")
                filterChip(title: "Diziler")
            }
        }
    }

    private func filterChip(title: String) -> some View {
        let isSelected = filterType == title
        return Button {
            withAnimation(.spring(response: 0.3)) {
                filterType = title
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.creamAccent : AppTheme.text.opacity(0.05))
                .foregroundColor(isSelected ? Color(hex: "0F172A") : AppTheme.text.opacity(0.6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? .clear : AppTheme.text.opacity(0.1), lineWidth: 1)
                )
        }
    }

    // MARK: - Media Grid

    private var mediaGrid: some View {
        Group {
            if apiResults.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("İçerik yükleniyor...")
                        .foregroundColor(AppTheme.text.opacity(0.4))
                    Button("Tekrar Dene") { 
                        Task { await fetchInitialMedia() }
                    }
                    .foregroundColor(AppTheme.accent)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filtered, id: \.id) { result in
                        mediaCard(result)
                    }
                }
            }
        }
    }

    private func mediaCard(_ result: TMDBSearchResult) -> some View {
        let added = isInMyList(result)
        
        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // TMDB Poster
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.text.opacity(0.05))
                    .overlay {
                        if let urlString = result.posterURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                         .scaledToFill()
                                case .failure(_):
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 30))
                                        Text(result.displayName)
                                            .font(.caption2)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 4)
                                    }
                                    .foregroundColor(AppTheme.text.opacity(0.15))
                                case .empty:
                                    ProgressView()
                                        .tint(AppTheme.accent)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: result.mediaType == .movie ? "film" : "tv")
                                        .font(.system(size: 30))
                                    Text(result.displayName)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                                .foregroundColor(AppTheme.text.opacity(0.15))
                            }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                
                // Add/Remove Button
                Button {
                    toggle(result)
                } label: {
                    ZStack {
                        Circle()
                            .fill(added ? AppTheme.text.opacity(0.4) : AppTheme.creamAccent)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: added ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(added ? .white : Color(hex: "0F172A"))
                    }
                    .padding(12)
                }
            }
            
            Text(result.displayName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.text)
                .lineLimit(1)
        }
    }

    // MARK: - Logic

    private var filtered: [TMDBSearchResult] {
        return apiResults
    }

    private func searchMedia(query: String) {
        searchTask?.cancel()
        
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            Task { await fetchInitialMedia() }
            return
        }

        let type: MediaType = filterType == "Diziler" ? .series : .movie

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            do {
                if filterType == "Popüler" {
                    async let movies = TMDBService.shared.search(query: q, type: .movie)
                    async let series = TMDBService.shared.search(query: q, type: .series)
                    let (mResults, sResults) = try await (movies, series)
                    
                    var combined: [TMDBSearchResult] = []
                    let maxCount = max(mResults.count, sResults.count)
                    for i in 0..<maxCount {
                        if i < mResults.count { combined.append(mResults[i]) }
                        if i < sResults.count { combined.append(sResults[i]) }
                    }
                    
                    if !Task.isCancelled {
                        await MainActor.run { self.apiResults = combined }
                    }
                } else {
                    let type: MediaType = filterType == "Diziler" ? .series : .movie
                    let results = try await TMDBService.shared.search(query: q, type: type)
                    if !Task.isCancelled {
                        await MainActor.run { self.apiResults = results }
                    }
                }
            } catch {
                print("TMDB Search Error: \(error)")
            }
        }
    }

    private func fetchInitialMedia() async {
        do {
            if filterType == "Popüler" {
                // Fetch both movies and series for Popular
                async let movies = TMDBService.shared.fetchPopular(type: .movie)
                async let series = TMDBService.shared.fetchPopular(type: .series)
                
                let (mResults, sResults) = try await (movies, series)
                
                // Mix them roughly
                var combined: [TMDBSearchResult] = []
                let maxCount = max(mResults.count, sResults.count)
                for i in 0..<maxCount {
                    if i < mResults.count { combined.append(mResults[i]) }
                    if i < sResults.count { combined.append(sResults[i]) }
                }
                
                await MainActor.run {
                    self.apiResults = combined
                }
            } else {
                let type: MediaType = filterType == "Diziler" ? .series : .movie
                let results = try await TMDBService.shared.fetchPopular(type: type)
                await MainActor.run {
                    self.apiResults = results
                }
            }
        } catch {
            print("TMDB Popular Error: \(error)")
        }
    }

    private func isInMyList(_ result: TMDBSearchResult) -> Bool {
        guard let me = session.currentProfile else { return false }
        return profileMedia.contains(where: { link in
            link.profileId == me.id && mediaItems.first(where: { $0.id == link.mediaId })?.tmdbId == result.id
        })
    }

    private func toggle(_ result: TMDBSearchResult) {
        if isInMyList(result) {
            remove(result)
        } else {
            add(result)
        }
    }

    private func add(_ result: TMDBSearchResult) {
        guard let me = session.currentProfile else { return }
        
        let type: MediaType = filterType == "Diziler" ? .series : .movie
        let existingItem = mediaItems.first(where: { $0.tmdbId == result.id })
        let mediaItem: MediaItem
        
        if let existing = existingItem {
            mediaItem = existing
        } else {
            mediaItem = MediaItem(
                title: result.displayName,
                type: type,
                tmdbId: result.id,
                posterPath: result.poster_path,
                backdropPath: result.backdrop_path
            )
            modelContext.insert(mediaItem)
        }
        
        if !isInMyList(result) {
            modelContext.insert(ProfileMedia(profileId: me.id, mediaId: mediaItem.id))
        }
        
        try? modelContext.save()
    }

    private func remove(_ result: TMDBSearchResult) {
        guard let me = session.currentProfile else { return }
        
        let existingItem = mediaItems.first(where: { $0.tmdbId == result.id })
        guard let mediaItem = existingItem else { return }
        
        let toDelete = profileMedia.filter { $0.profileId == me.id && $0.mediaId == mediaItem.id }
        for l in toDelete { modelContext.delete(l) }
        
        try? modelContext.save()
    }
}
