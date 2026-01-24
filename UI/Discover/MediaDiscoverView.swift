import SwiftUI
import SwiftData

struct MediaDiscoverView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @Query private var items: [MediaItem]
    @Query private var links: [ProfileMedia]

    @State private var selectedType: MediaType = .movie
    @State private var queryText: String = ""

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
            .task { seedMediaIfNeeded() }
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
                        EmptyStateView(title: "Sonuç yok", subtitle: "Farklı bir arama deneyebilirsin.")
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(list, id: \.id) { item in
                                MediaRow(
                                    item: item,
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

    private func filteredItems() -> [MediaItem] {
        let base = items.filter { $0.type == selectedType }
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base.sorted(by: { $0.createdAt > $1.createdAt }) }

        return base
            .filter { $0.title.lowercased().contains(q) }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func isAdded(_ item: MediaItem) -> Bool {
        guard let me = session.currentProfile else { return false }
        return links.contains(where: { $0.profileId == me.id && $0.mediaId == item.id })
    }

    private func add(_ item: MediaItem) {
        guard let me = session.currentProfile else { return }
        if isAdded(item) { return }
        modelContext.insert(ProfileMedia(profileId: me.id, mediaId: item.id))
        try? modelContext.save()
    }

    private func remove(_ item: MediaItem) {
        guard let me = session.currentProfile else { return }
        let toDelete = links.filter { $0.profileId == me.id && $0.mediaId == item.id }
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
    let item: MediaItem
    let isAdded: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
                    .frame(width: 56, height: 56)

                Image(systemName: item.type == .movie ? "film" : "tv")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)

                Text(item.type == .movie ? "Film" : "Dizi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isAdded ? onRemove() : onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isAdded ? .green : .blue)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
