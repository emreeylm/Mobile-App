import SwiftUI
import SwiftData

struct LikesView: View {

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var likeEdges: [LikeEdge]
    @Query private var profiles: [Profile]

    @State private var selectedTab: Int = 0
    @State private var showPaywall = false

    // Backend'den gelen beğeniler
    @State private var backendLikes: [LikeEntry] = []
    @State private var errorMessage: String? = nil
    @State private var unlockedLikeIds: Set<String> = []
    @State private var selectedEntryToUnlock: LikeEntry? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Beğeniler")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    customTabBar

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if !subscriptionStore.canSeeWhoLikedYou {
                                PremiumBanner()
                                    .padding(.bottom, 8)
                            }

                            if selectedTab == 0 {
                                beğenilerSection
                            } else if selectedTab == 1 {
                                superlikesSection
                            } else {
                                beğendiklerimSection
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            .task { await refreshLikes() }
            .alert("Bağlantı Hatası", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Tamam") { errorMessage = nil }
                Button("Tekrar Dene") { Task { await refreshLikes() } }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .alert("Profili Kilidini Aç", isPresented: Binding(
            get: { selectedEntryToUnlock != nil },
            set: { if !$0 { selectedEntryToUnlock = nil } }
        ), presenting: selectedEntryToUnlock) { entry in
            Button("Premium'a Geç") {
                showPaywall = true
            }
            Button("Reklam İzle") {
                unlockWithAd(entry)
            }
            Button("İptal", role: .cancel) {}
        } message: { entry in
            Text("Bu profili görmek için Premium'a geçebilir veya 1 kısa reklam izleyebilirsiniz.")
        }
    }

    // MARK: - Tab sections

    @ViewBuilder
    private var beğenilerSection: some View {
        if backendLikes.isEmpty {
            emptyStateView(tab: 0)
        } else {
            ForEach(backendLikes, id: \.id) { entry in
                let isUnlocked = unlockedLikeIds.contains(entry.id)
                let canSee = (subscriptionStore.canSeeWhoLikedYou && !entry.blur) || isUnlocked
                if canSee {
                    let displayEntry = isUnlocked ? entry.deblurred : entry
                    BackendLikeRow(
                        entry: displayEntry,
                        onAccept: { acceptBackendLike(displayEntry) },
                        onReject: { rejectBackendLike(displayEntry) }
                    )
                } else {
                    Button {
                        selectedEntryToUnlock = entry
                    } label: {
                        BackendLikeRow(
                            entry: entry.blurred,
                            onAccept: { selectedEntryToUnlock = entry },
                            onReject: { selectedEntryToUnlock = entry }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var superlikesSection: some View {
        let items = incomingSuperLikes
        if items.isEmpty {
            emptyStateView(tab: 1)
        } else {
            ForEach(items, id: \.id) { profile in
                if subscriptionStore.canSeeWhoLikedYou {
                    let edge = likeEdges.first(where: { $0.fromProfileId == profile.id && $0.toProfileId == myProfileId })
                    LikeRow(
                        profile: profile,
                        isSuperLike: true,
                        isBlurred: false,
                        onAccept: { if let e = edge { acceptLike(e, other: profile) } },
                        onReject: { if let e = edge { rejectLike(e) } }
                    )
                } else {
                    Button { showPaywall = true } label: {
                        LikeRow(profile: profile, isSuperLike: true, isBlurred: true,
                                onAccept: { showPaywall = true }, onReject: { showPaywall = true })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var beğendiklerimSection: some View {
        let items = outgoingLikes
        if items.isEmpty {
            VStack(spacing: 16) {
                Spacer(minLength: 100)
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.text.opacity(0.1))
                Text("Henüz kimseyi beğenmediniz")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text.opacity(0.4))
            }
        } else {
            ForEach(items, id: \.id) { edge in
                if let profile = profiles.first(where: { $0.id == edge.toProfileId }) {
                    OutgoingLikeRow(
                        profile: profile,
                        isSuperLike: edge.isSuperLike,
                        onSuperLike: {
                            guard !edge.isSuperLike else { return }
                            guard subscriptionStore.consumeSuperLike() else {
                                showPaywall = true
                                return
                            }
                            edge.isSuperLike = true
                            try? modelContext.save()
                            Task {
                                _ = try? await APIClient.shared.sendVipTicket(toId: profile.ownerUserId, message: nil)
                            }
                        },
                        onUnlike: {
                            modelContext.delete(edge)
                            try? modelContext.save()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Custom tab bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Beğenenler", index: 0)
            tabButton(title: "Superlikes", index: 1)
            tabButton(title: "Beğendiklerim", index: 2)
        }
        .padding(.top, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.text.opacity(0.1)).frame(height: 1)
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index }
        } label: {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .semibold))
                    .foregroundStyle(selectedTab == index ? AppTheme.accent : AppTheme.text.opacity(0.5))
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(height: 3)
                    .opacity(selectedTab == index ? 1 : 0)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyStateView(tab: Int) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)
            Image(systemName: tab == 0 ? "heart.slash.fill" : "star.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.text.opacity(0.1))
            Text(tab == 0 ? "Henüz sizi beğenen yok" : "Henüz superlike atan yok")
                .font(.headline)
                .foregroundStyle(AppTheme.text.opacity(0.4))
            Text("Profilinizi güncelleyerek daha fazla ilgi çekebilirsiniz.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Backend fetch

    private func refreshLikes() async {
        do {
            let resp = try await APIClient.shared.getLikes()
            backendLikes = resp.likes
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Backend actions

    private func acceptBackendLike(_ entry: LikeEntry) {
        guard let meId = myProfileId else { return }
        Task {
            do {
                let resp = try await APIClient.shared.swipe(targetId: entry.id, direction: "like")
                if resp.eslesme_oldu {
                    let otherProfile = getOrCreateProfileStub(
                        backendId: entry.id,
                        isim: entry.isim ?? "Kullanıcı",
                        yas: entry.yas
                    )
                    let m1 = Match(myProfileId: meId, otherProfileId: otherProfile.id)
                    let m2 = Match(myProfileId: otherProfile.id, otherProfileId: meId)
                    let thread = ChatThread(myProfileId: meId, otherProfileId: otherProfile.id)
                    modelContext.insert(m1); modelContext.insert(m2); modelContext.insert(thread)
                    try? modelContext.save()
                }
                backendLikes.removeAll { $0.id == entry.id }
            } catch {
                backendLikes.removeAll { $0.id == entry.id }
            }
        }
    }

    private func rejectBackendLike(_ entry: LikeEntry) {
        Task {
            _ = try? await APIClient.shared.swipe(targetId: entry.id, direction: "dislike")
            backendLikes.removeAll { $0.id == entry.id }
        }
    }

    // MARK: - Local actions (superlikes)

    private func acceptLike(_ edge: LikeEdge, other: Profile) {
        guard let meId = myProfileId else { return }
        let match1 = Match(myProfileId: meId, otherProfileId: other.id)
        let match2 = Match(myProfileId: other.id, otherProfileId: meId)
        let thread = ChatThread(myProfileId: meId, otherProfileId: other.id)
        modelContext.insert(match1); modelContext.insert(match2); modelContext.insert(thread)
        modelContext.delete(edge)
        try? modelContext.save()
    }

    private func rejectLike(_ edge: LikeEdge) {
        modelContext.delete(edge)
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func unlockWithAd(_ entry: LikeEntry) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }

        AdManager.shared.showRewardedAd(from: rootVC) { earned in
            if earned {
                withAnimation {
                    unlockedLikeIds.insert(entry.id)
                }
            }
        }
    }

    private var myProfileId: String? { session.currentProfile?.id }

    private var outgoingLikes: [LikeEdge] {
        guard let me = myProfileId else { return [] }
        return likeEdges
            .filter { $0.fromProfileId == me }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var incomingSuperLikes: [Profile] {
        guard let me = myProfileId else { return [] }
        let fromIds = likeEdges
            .filter { $0.toProfileId == me && $0.isLike && $0.isSuperLike }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.fromProfileId }
        return profiles.filter { fromIds.contains($0.id) }
    }

    private func getOrCreateProfileStub(backendId: String, isim: String, yas: Int) -> Profile {
        if let existing = profiles.first(where: { $0.ownerUserId == backendId }) { return existing }
        let bday = Calendar.current.date(byAdding: .year, value: -yas, to: .now) ?? .now
        let stub = Profile(ownerUserId: backendId, firstName: isim, lastName: "", bio: "",
                           gender: .other, lookingForGender: .everyone, birthday: bday)
        modelContext.insert(stub)
        return stub
    }
}

// MARK: - Backend like row

private struct BackendLikeRow: View {
    let entry: LikeEntry
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                if entry.blur {
                    Text("Gizli Profil")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                } else {
                    Text("\(entry.isim ?? ""), \(entry.yas)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                }
                Text("Sizi beğendi • Yakın zamanda")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                Button { onAccept() } label: {
                    ZStack {
                        Circle().fill(AppTheme.accent.opacity(0.1)).frame(width: 36, height: 36)
                        Image(systemName: "heart.fill").font(.system(size: 16)).foregroundStyle(AppTheme.accent)
                    }
                }
                Button { onReject() } label: {
                    ZStack {
                        Circle().fill(AppTheme.text.opacity(0.05)).frame(width: 36, height: 36)
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(AppTheme.text.opacity(0.6))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .frame(width: 64, height: 64)
            if entry.blur {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.system(size: 18))
            } else {
                Text(entry.isim?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
            }
        }
        .blur(radius: entry.blur ? 12 : 0)
        .overlay {
            if entry.blur {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.1))
                Image(systemName: "lock.fill").foregroundStyle(AppTheme.accent).font(.system(size: 18))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Local profile like row (superlikes)

private struct LikeRow: View {
    let profile: Profile
    let isSuperLike: Bool
    var isBlurred: Bool = false
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                if isBlurred {
                    Text("Gizli Profil")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                } else {
                    Text("\(profile.name), \(profile.age)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                }
                Text(isSuperLike ? "Super Liked • Yakın zamanda" : "Sizi beğendi • Yakın zamanda")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                Button { onAccept() } label: {
                    ZStack {
                        Circle()
                            .fill(isSuperLike ? Color.blue.opacity(0.1) : AppTheme.accent.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: isSuperLike ? "star.fill" : "heart.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(isSuperLike ? .blue : AppTheme.accent)
                    }
                }
                Button { onReject() } label: {
                    ZStack {
                        Circle().fill(AppTheme.text.opacity(0.05)).frame(width: 36, height: 36)
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(AppTheme.text.opacity(0.6))
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
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    AppTheme.surface
                    Image(systemName: "person.fill").foregroundStyle(AppTheme.text.opacity(0.3))
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.text.opacity(0.05), lineWidth: 1))
        .blur(radius: isBlurred ? 12 : 0)
        .overlay {
            if isBlurred {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.accent.opacity(0.1))
                Image(systemName: "lock.fill").foregroundStyle(AppTheme.accent).font(.system(size: 18))
            }
        }
    }
}

// MARK: - Outgoing like row

private struct OutgoingLikeRow: View {
    let profile: Profile
    let isSuperLike: Bool
    var onSuperLike: () -> Void
    var onUnlike: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                if let d = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                   let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Circle().fill(AppTheme.surface)
                    Image(systemName: "person.fill").foregroundStyle(AppTheme.text.opacity(0.4))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(profile.firstName), \(profile.calculatedAge)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    if isSuperLike {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                    }
                }
                Text(isSuperLike ? "Superlike gönderildi" : "Beğenildi")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 10) {
                if !isSuperLike {
                    Button(action: onSuperLike) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.yellow)
                            .frame(width: 38, height: 38)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                Button(action: onUnlike) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(AppTheme.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - LikeEntry helper

private extension LikeEntry {
    var blurred: LikeEntry {
        LikeEntry(id: id, yas: yas, tarih: tarih, blur: true, isim: nil, now_watching: nil)
    }
    var deblurred: LikeEntry {
        LikeEntry(id: id, yas: yas, tarih: tarih, blur: false, isim: isim ?? "Kullanıcı", now_watching: now_watching)
    }
}
