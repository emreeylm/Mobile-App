import SwiftUI
import SwiftData

struct DiscoverView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @Query private var mediaItems: [MediaItem]
    @Query private var profileMedia: [ProfileMedia]

    @State private var filterType: String = "Tümü" // Tümü, Filmler, Diziler
    @State private var search: String = ""

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
        .onAppear { seedIfNeeded() }
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
                filterChip(title: "Tümü")
                filterChip(title: "Filmler")
                filterChip(title: "Diziler")
                filterChip(title: "Popüler")
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
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(filtered, id: \.id) { item in
                mediaCard(item)
            }
        }
    }

    private func mediaCard(_ item: MediaItem) -> some View {
        let added = isInMyList(item)
        
        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // Placeholder poster
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.text.opacity(0.05))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: item.posterSymbol)
                                .font(.system(size: 30))
                                .foregroundStyle(AppTheme.text.opacity(0.1))
                            
                            // Visual flavor for different cards
                            if item.title == "Inception" {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LinearGradient(colors: [.blue, .orange], startPoint: .top, endPoint: .bottom))
                            } else if item.title == "Interstellar" {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LinearGradient(colors: [.yellow, .black], startPoint: .top, endPoint: .bottom))
                            }
                        }
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                
                // Add/Remove Button
                Button {
                    toggle(item)
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
            
            Text(item.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.text)
                .lineLimit(1)
        }
    }

    // MARK: - Logic

    private var filtered: [MediaItem] {
        let s = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        return mediaItems
            .filter { item in
                if filterType == "Filmler" { return item.type == .movie }
                if filterType == "Diziler" { return item.type == .series }
                return true
            }
            .filter { s.isEmpty ? true : $0.title.lowercased().contains(s) }
            .sorted { $0.title < $1.title }
    }

    private func isInMyList(_ item: MediaItem) -> Bool {
        guard let me = session.currentProfile else { return false }
        return profileMedia.contains(where: { $0.profileId == me.id && $0.mediaId == item.id })
    }

    private func toggle(_ item: MediaItem) {
        guard let me = session.currentProfile else { return }
        if let existing = profileMedia.first(where: { $0.profileId == me.id && $0.mediaId == item.id }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(ProfileMedia(profileId: me.id, mediaId: item.id))
        }
    }

    private func seedIfNeeded() {
        if mediaItems.isEmpty == false { return }
        
        let movies = [
            "Inception", "Interstellar", "The Godfather", "Blade Runner 2049", 
            "The Dark Knight", "Fight Club", "The Matrix", "Joker"
        ].map { MediaItem(title: $0, type: .movie) }

        let series = [
            "Breaking Bad", "Dark", "Sherlock", "The Office", "Stranger Things", "The Boys"
        ].map { MediaItem(title: $0, type: .series) }

        for m in (movies + series) { modelContext.insert(m) }
    }
}
