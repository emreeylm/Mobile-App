import SwiftUI
import SwiftData

struct LikesView: View {

    @EnvironmentObject var session: SessionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var likeEdges: [LikeEdge]
    @Query private var profiles: [Profile]

    @State private var selectedTab: Int = 0 // 0: Likes, 1: Superlikes

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerArea
                    
                    // Custom Tab Bar
                    customTabBar
                    
                    // List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let items = selectedTab == 0 ? incomingLikes : incomingSuperLikes
                            
                            if items.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(items, id: \.id) { profile in
                                    NavigationLink {
                                        ProfilePreviewView(profile: profile)
                                    } label: {
                                        let edge = likeEdges.first(where: { $0.fromProfileId == profile.id && $0.toProfileId == myProfileId })
                                        LikeRow(
                                            profile: profile,
                                            isSuperLike: selectedTab == 1,
                                            onAccept: {
                                                if let edge = edge {
                                                    acceptLike(edge, other: profile)
                                                }
                                            },
                                            onReject: {
                                                if let edge = edge {
                                                    rejectLike(edge)
                                                }
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Components

    private var headerArea: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
            }
            
            Spacer()
            
            Text("Beğeniler")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Beğenenler", index: 0)
            tabButton(title: "Superlikes", index: 1)
        }
        .padding(.top, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.text.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .semibold))
                    .foregroundStyle(selectedTab == index ? AppTheme.accent : AppTheme.text.opacity(0.5))
                
                // Active Underline
                ZStack {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(height: 3)
                        .opacity(selectedTab == index ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)
            Image(systemName: selectedTab == 0 ? "heart.slash.fill" : "star.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.text.opacity(0.1))
            
            Text(selectedTab == 0 ? "Henüz sizi beğenen yok" : "Henüz superlike atan yok")
                .font(.headline)
                .foregroundStyle(AppTheme.text.opacity(0.4))
            
            Text("Profilinizi güncelleyerek daha fazla ilgi çekebilirsiniz.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                DemoSeeder.populateInteractions(context: modelContext)
            } label: {
                Text("Verileri Doldur (Demo)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.main)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Computed Data

    private var myProfileId: String? { session.currentProfile?.id }

    private var incomingLikes: [Profile] {
        guard let me = myProfileId else { return [] }
        let fromIds = likeEdges
            .filter { $0.toProfileId == me && $0.isLike && !$0.isSuperLike }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.fromProfileId }

        return profiles.filter { fromIds.contains($0.id) }
    }

    private var incomingSuperLikes: [Profile] {
        guard let me = myProfileId else { return [] }
        let fromIds = likeEdges
            .filter { $0.toProfileId == me && $0.isLike && $0.isSuperLike }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.fromProfileId }

        return profiles.filter { fromIds.contains($0.id) }
    }

    private func acceptLike(_ edge: LikeEdge, other: Profile) {
        guard let meId = myProfileId else { return }
        
        // 1. Create Match
        let match = Match(myProfileId: meId, otherProfileId: other.id)
        modelContext.insert(match)
        
        // 2. Create ChatThread
        let thread = ChatThread(myProfileId: meId, otherProfileId: other.id)
        modelContext.insert(thread)
        
        // 3. Delete the LikeEdge (it's now a match)
        modelContext.delete(edge)
        
        try? modelContext.save()
    }

    private func rejectLike(_ edge: LikeEdge) {
        modelContext.delete(edge)
        try? modelContext.save()
    }
}

private struct LikeRow: View {
    let profile: Profile
    let isSuperLike: Bool
    
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            // Avatar
            avatarView
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(profile.name), \(profile.age)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                
                Text(isSuperLike ? "Super Liked • 1sa önce" : "Sizi beğendi • 2sa önce")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Accept/Like Button
                Button {
                    onAccept()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isSuperLike ? Color.blue.opacity(0.1) : AppTheme.accent.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: isSuperLike ? "star.fill" : "heart.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(isSuperLike ? .blue : AppTheme.accent)
                    }
                }

                // Reject Button
                Button {
                    onReject()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.text.opacity(0.05))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.text.opacity(0.6))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        Group {
            if let data = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.surface
                    Image(systemName: "person.fill")
                        .foregroundStyle(AppTheme.text.opacity(0.3))
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.text.opacity(0.05), lineWidth: 1)
        )
    }
}
