import SwiftUI
import SwiftData
import os

struct MediaDiscoverView: View {
    private let logger = Logger(subsystem: "com.bingedate", category: "MediaDiscoverView")

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @Query private var items: [MediaItem]
    @Query private var links: [ProfileMedia]

    @State private var selectedType: MediaType = .movie
    @State private var queryText: String = ""
    @State private var apiResults: [TMDBSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isInitialLoad = true

    private let headerHeight: CGFloat = 44
    private let titleTopExtra: CGFloat = 26
    private let contentTopExtra: CGFloat = 38

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()

                header
                    .padding(.top, geo.safeAreaInsets.top + titleTopExtra)

                content
                    .padding(.top, geo.safeAreaInsets.top + headerHeight + contentTopExtra)
            }
            .ignoresSafeArea(.container, edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .task { 
                if isInitialLoad {
                    await fetchInitialMedia()
                    isInitialLoad = false
                }
            }
            .onChange(of: queryText) { _, newValue in
                searchMedia(query: newValue, type: selectedType)
            }
            .onChange(of: selectedType) { _, newValue in
                if queryText.isEmpty {
                    Task { await fetchInitialMedia() }
                } else {
                    searchMedia(query: queryText, type: newValue)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filmler & Diziler")
                .font(.system(size: 34, weight: .bold))
                .padding(.horizontal, 16)

            Picker("Tür", selection: $selectedType) {
                Text("Filmler").tag(MediaType.movie)
                Text("Diziler").tag(MediaType.series)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Ara...", text: $queryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: headerHeight + 108, alignment: .bottom)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.currentProfile == nil {
                    EmptyStateView(title: "Profil yok", subtitle: "Profil oluşturunca içerik ekleyebilirsin.")
                        .padding(.top, 20)
                } else {
                    let list = filteredItems()

                    if list.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                            Text("İçerik yükleniyor...")
                                .foregroundColor(AppTheme.text.opacity(0.4))
                            Button("Tekrar Dene") { 
                                Task { await fetchInitialMedia() }
                            }
                            .foregroundColor(AppTheme.accent)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(list, id: \.id) { item in
                                MediaRow(
                                    result: item,
                                    isAdded: isAdded(item),
                                    onAdd: { add(item) },
                                    onRemove: { remove(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Logic

    private func filteredItems() -> [TMDBSearchResult] {
        return apiResults
    }

    private func searchMedia(query: String, type: MediaType) {
        searchTask?.cancel()
        
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            Task { await fetchInitialMedia() }
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            do {
                let results = try await TMDBService.shared.search(query: q, type: type)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.apiResults = results
                    }
                }
            } catch {
                logger.warning("TMDB search error: \(error)")
            }
        }
    }

    private func fetchInitialMedia() async {
        do {
            let results = try await TMDBService.shared.fetchPopular(type: selectedType)
            await MainActor.run {
                self.apiResults = results
            }
        } catch {
            logger.warning("TMDB popular fetch error: \(error)")
        }
    }

    private func isAdded(_ result: TMDBSearchResult) -> Bool {
        guard let me = session.currentProfile else { return false }
        // We need to check if a MediaItem with this tmdbId already exists and is linked
        return links.contains(where: { link in
            link.profileId == me.id && items.first(where: { $0.id == link.mediaId })?.tmdbId == result.id
        })
    }

    private func add(_ result: TMDBSearchResult) {
        guard let me = session.currentProfile else { return }
        
        // 1. Find or create MediaItem
        let existingItem = items.first(where: { $0.tmdbId == result.id })
        let mediaItem: MediaItem
        
        if let existing = existingItem {
            mediaItem = existing
        } else {
            mediaItem = MediaItem(
                title: result.displayName,
                type: selectedType,
                tmdbId: result.id,
                posterPath: result.poster_path,
                backdropPath: result.backdrop_path
            )
            modelContext.insert(mediaItem)
        }
        
        // 2. Link to profile
        if !isAdded(result) {
            modelContext.insert(ProfileMedia(profileId: me.id, mediaId: mediaItem.id))
        }
        
        try? modelContext.save()
    }

    private func remove(_ result: TMDBSearchResult) {
        guard let me = session.currentProfile else { return }
        
        let existingItem = items.first(where: { $0.tmdbId == result.id })
        guard let mediaItem = existingItem else { return }
        
        let toDelete = links.filter { $0.profileId == me.id && $0.mediaId == mediaItem.id }
        for l in toDelete { modelContext.delete(l) }
        
        try? modelContext.save()
    }

    private func seedMediaIfNeeded() {
        guard items.isEmpty else { return }

        let seed: [(String, MediaType)] = [
            ("Interstellar", .movie),
            ("Inception", .movie),
            ("The Dark Knight", .movie),
            ("Whiplash", .movie),
            ("The Matrix", .movie),

            ("Breaking Bad", .series),
            ("Dark", .series),
            ("Peaky Blinders", .series),
            ("Stranger Things", .series),
            ("The Office", .series),
            ("Better Call Saul", .series)
        ]

        for (title, type) in seed {
            modelContext.insert(MediaItem(title: title, type: type))
        }
        try? modelContext.save()
    }
}

// MARK: - Row

private struct MediaRow: View {
    let result: TMDBSearchResult
    let isAdded: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.text.opacity(0.05))
                    .frame(width: 56, height: 80)

                if let urlString = result.posterURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                 .scaledToFill()
                        case .failure(_):
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.accent.opacity(0.3))
                        case .empty:
                            ProgressView()
                                .tint(AppTheme.accent)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 56, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.text)

                Text(result.release_date?.prefix(4) ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }

            Spacer()

            Button {
                isAdded ? onRemove() : onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isAdded ? .green : AppTheme.accent)
            }
        }
        .padding(12)
        .background(AppTheme.text.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
