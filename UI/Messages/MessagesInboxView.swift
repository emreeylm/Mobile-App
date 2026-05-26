import SwiftUI
import SwiftData

struct MessagesInboxView: View {

    @EnvironmentObject var session: SessionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var threads: [ChatThread]
    @Query private var profiles: [Profile]
    @Query private var matches: [Match] // ✅ Added matches query for "New Matches"
    @Query private var messages: [ChatMessage]

    @State private var searchText = ""
    @State private var backendMatches: [MatchEntry] = []
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerArea

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            searchBarArea
                            newMatchesSection
                            conversationsSection
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await fetchBackendMatches() }
            .alert("Bağlantı Hatası", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Tamam") { errorMessage = nil }
                Button("Tekrar Dene") { Task { await fetchBackendMatches() } }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func fetchBackendMatches() async {
        do {
            let resp = try await APIClient.shared.getMatches()
            backendMatches = resp.matches
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var filteredBackendMatches: [MatchEntry] {
        guard !searchText.isEmpty else { return backendMatches }
        let query = searchText.lowercased()
        return backendMatches.filter { $0.isim.lowercased().contains(query) }
    }

    // MARK: - Components

    private var headerArea: some View {
        HStack {
            Text("Mesajlar")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchBarArea: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.text.opacity(0.4))
            
            TextField("", text: $searchText, prompt: Text("Sohbetlerde ara...").foregroundColor(AppTheme.text.opacity(0.3)))
                .foregroundColor(AppTheme.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 16)
    }

    private var newMatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YENİ EŞLEŞMELER")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.accent.opacity(0.7))

                Spacer()

                let totalNew = backendMatches.isEmpty ? newMatches.count : backendMatches.count
                if totalNew > 0 {
                    Text("\(totalNew) Yeni")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    if backendMatches.isEmpty {
                        // Backend bağlantısı yokken yerel eşleşmeleri göster
                        ForEach(newMatches, id: \.id) { match in
                            if let other = otherProfile(forMatch: match) {
                                NavigationLink { ChatView(otherProfile: other) } label: {
                                    MatchCircle(profile: other)
                                }
                            }
                        }
                    } else {
                        ForEach(filteredBackendMatches, id: \.id) { entry in
                            NavigationLink {
                                ChatView(otherProfile: getOrCreateProfileStub(entry: entry))
                            } label: {
                                BackendMatchCircle(entry: entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SOHBETLER")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.accent.opacity(0.7))
                .padding(.horizontal, 16)

            if myThreads.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 40)
                    Image(systemName: "message.badge.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.text.opacity(0.1))
                    Text("Henüz sohbet yok")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text.opacity(0.3))
                    Text("Eşleşmelerinden biriyle sohbet başlat.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.text.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(myThreads, id: \.id) { t in
                        if let other = otherProfile(for: t) {
                            NavigationLink {
                                ChatView(thread: t, otherProfile: other)
                            } label: {
                                InboxRow(
                                    profile: other,
                                    subtitle: lastMessageText(threadId: t.id),
                                    unreadCount: unreadCount(threadId: t.id),
                                    time: lastMessageTime(threadId: t.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private var myProfileId: String? { session.currentProfile?.id }

    private var myThreads: [ChatThread] {
        guard let me = myProfileId else { return [] }
        let active = threads
            .filter { t in
                t.myProfileId == me && !messages.filter({ $0.threadId == t.id }).isEmpty
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        guard !searchText.isEmpty else { return active }
        let query = searchText.lowercased()
        return active.filter { t in
            // Profil adına veya son mesaj metnine göre filtrele
            if let profile = profiles.first(where: { $0.id == t.otherProfileId }),
               profile.firstName.lowercased().contains(query) {
                return true
            }
            return lastMessageText(threadId: t.id).lowercased().contains(query)
        }
    }

    private var newMatches: [Match] {
        guard let me = myProfileId else { return [] }
        let all = matches.filter { match in
            guard match.myProfileId == me else { return false }
            if let thread = threads.first(where: { $0.myProfileId == me && $0.otherProfileId == match.otherProfileId }) {
                return messages.filter { $0.threadId == thread.id }.isEmpty
            }
            return true
        }
        guard !searchText.isEmpty else { return all }
        let query = searchText.lowercased()
        return all.filter { match in
            if let profile = profiles.first(where: { $0.id == match.otherProfileId }) {
                return profile.firstName.lowercased().contains(query)
            }
            return false
        }
    }

    private func otherProfile(for thread: ChatThread) -> Profile? {
        profiles.first(where: { $0.id == thread.otherProfileId })
    }
    
    private func otherProfile(forMatch match: Match) -> Profile? {
        profiles.first(where: { $0.id == match.otherProfileId })
    }

    private func lastMessageText(threadId: String) -> String {
        let last = messages
            .filter { $0.threadId == threadId }
            .sorted { $0.createdAt > $1.createdAt }
            .first
        return last?.text ?? "Sohbete devam et"
    }
    
    private func lastMessageTime(threadId: String) -> String {
        guard let last = messages.filter({ $0.threadId == threadId }).sorted(by: { $0.createdAt > $1.createdAt }).first else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(last.createdAt) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: last.createdAt)
        } else if cal.isDateInYesterday(last.createdAt) {
            return "Dün"
        } else {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: last.createdAt)
        }
    }

    private func unreadCount(threadId: String) -> Int {
        guard let me = session.currentProfile else { return 0 }
        return messages.filter { $0.threadId == threadId && !$0.isRead && $0.senderProfileId != me.id }.count
    }

    /// Backend MatchEntry için yerel Profile stub oluşturur / bulur.
    private func getOrCreateProfileStub(entry: MatchEntry) -> Profile {
        if let existing = profiles.first(where: { $0.ownerUserId == entry.id }) { return existing }
        let bday = Calendar.current.date(byAdding: .year, value: -entry.yas, to: .now) ?? .now
        let stub = Profile(ownerUserId: entry.id, firstName: entry.isim, lastName: "", bio: "",
                           gender: .other, lookingForGender: .everyone, birthday: bday)
        modelContext.insert(stub)
        return stub
    }
}

// MARK: - Row Components

private struct BackendMatchCircle: View {
    let entry: MatchEntry
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(AppTheme.surface)
                    Text(String(entry.isim.prefix(1).uppercased()))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                }
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2))

                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                    .padding(2)
            }
            Text(entry.isim)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.text)
        }
    }
}

private struct MatchCircle: View {
    let profile: Profile
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let d = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                       let ui = UIImage(data: d) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(AppTheme.surface)
                            Image(systemName: "person.fill").foregroundStyle(AppTheme.text.opacity(0.3))
                        }
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2))
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                    .padding(2)
            }
            
            Text(profile.firstName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.text)
        }
    }
}

private struct InboxRow: View {
    let profile: Profile
    let subtitle: String
    let unreadCount: Int
    let time: String

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let d = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                       let ui = UIImage(data: d) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(AppTheme.surface)
                            Image(systemName: "person.fill").foregroundStyle(AppTheme.text.opacity(0.3))
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
                    .padding(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.firstName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    
                    Spacer()
                    
                    Text(time)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                }

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
                    .lineLimit(1)
            }
            
            if unreadCount > 0 {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear) // To ensure tapping works everywhere
    }
}
