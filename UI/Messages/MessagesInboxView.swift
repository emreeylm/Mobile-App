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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Area (Custom)
                    headerArea
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Search Bar
                            searchBarArea
                            
                            // New Matches Section
                            newMatchesSection
                            
                            // Conversations Section
                            conversationsSection
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
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
            
            Text("Mesajlar")
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

    private var searchBarArea: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.text.opacity(0.4))
            
            TextField("", text: $searchText, prompt: Text("Search matches...").foregroundColor(AppTheme.text.opacity(0.3)))
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
                Text("NEW MATCHES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.accent.opacity(0.7))
                
                Spacer()
                
                if newMatches.count > 0 {
                    Text("\(newMatches.count) New")
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
                    // Likes Circle (Placeholder like in reference)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(AppTheme.text.opacity(0.2))
                                .frame(width: 68, height: 68)
                            
                            Circle()
                                .fill(AppTheme.text.opacity(0.04))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text("2 Likes")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.text.opacity(0.4))
                                )
                        }
                        Text(" ") // Keeps alignment
                            .font(.system(size: 13))
                    }
                    
                    ForEach(newMatches, id: \.id) { match in
                        if let other = otherProfile(forMatch: match) {
                            NavigationLink {
                                ChatView(otherProfile: other)
                            } label: {
                                MatchCircle(profile: other)
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
            Text("CONVERSATIONS")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.accent.opacity(0.7))
                .padding(.horizontal, 16)
            
            if myThreads.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 40)
                    Image(systemName: "message")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.text.opacity(0.1))
                    Text("Henüz sohbet yok")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text.opacity(0.2))
                    
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
        return threads
            .filter { $0.myProfileId == me }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var newMatches: [Match] {
        guard let me = myProfileId else { return [] }
        // Matches where NO ChatThread exists yet
        return matches.filter { match in
            match.myProfileId == me && !threads.contains(where: { $0.myProfileId == me && $0.otherProfileId == match.otherProfileId })
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
}

// MARK: - Row Components

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
