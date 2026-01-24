import SwiftUI
import SwiftData

struct LikesView: View {

    @EnvironmentObject var session: SessionStore
    @Query private var likeEdges: [LikeEdge]
    @Query private var profiles: [Profile]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Beğeniler")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    ScrollView {
                        VStack(spacing: 12) {
                            SectionCard(
                                title: "Beni Beğenenler",
                                items: incomingLikes
                            )

                            SectionCard(
                                title: "Benim Beğendiklerim",
                                items: outgoingLikes
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Computed Lists

    private var myProfileId: String? { session.currentProfile?.id }

    private var incomingLikes: [Profile] {
        guard let me = myProfileId else { return [] }
        let fromIds = likeEdges
            .filter { $0.toProfileId == me && $0.isLike }
            .map { $0.fromProfileId }

        return profiles.filter { fromIds.contains($0.id) }
    }

    private var outgoingLikes: [Profile] {
        guard let me = myProfileId else { return [] }
        let toIds = likeEdges
            .filter { $0.fromProfileId == me && $0.isLike }
            .map { $0.toProfileId }

        return profiles.filter { toIds.contains($0.id) }
    }
}

// MARK: - Section UI

private struct SectionCard: View {

    let title: String
    let items: [Profile]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }

            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "heart.slash")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.text.opacity(0.2))
                    Text("Henüz kimse yok")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(items, id: \.id) { p in
                    LikeRow(profile: p)
                }
            }
        }
        .padding(14)
        .background(AppTheme.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Row

private struct LikeRow: View {

    let profile: Profile

    var body: some View {
        HStack(spacing: 12) {

            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text("\(profile.age) • \(profile.city)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.text.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.text.opacity(0.3))
        }
        .padding(12)
        .background(AppTheme.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.text.opacity(0.05), lineWidth: 1)
        )
    }

    private var avatar: some View {
        Group {
            if let data = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(AppTheme.text.opacity(0.2))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
    }
}
