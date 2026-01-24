import SwiftUI
import SwiftData

struct MessagesInboxView: View {

    @EnvironmentObject var session: SessionStore

    @Query private var threads: [ChatThread]
    @Query private var profiles: [Profile]
    @Query private var messages: [ChatMessage]   // ✅ son mesaj + badge için

    private var myThreads: [ChatThread] {
        guard let me = session.currentProfile else { return [] }
        return threads
            .filter { $0.myProfileId == me.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mesajlar")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    
                    if session.currentProfile == nil {
                        Text("Profil bulunamadı.")
                            .foregroundStyle(AppTheme.text.opacity(0.4))
                            .padding(.horizontal, 16)
                        Spacer()
                    } else if myThreads.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "message")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(AppTheme.text.opacity(0.3))
                            
                            Text("Henüz mesaj yok")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            
                            Text("Eşleşince burada sohbetler görünecek.")
                                .font(.callout)
                                .foregroundStyle(AppTheme.text.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 24)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                SwiftUI.ForEach(Array(myThreads), id: \ChatThread.id) { t in
                                    if let other = otherProfile(for: t) {
                                        SwiftUI.NavigationLink {
                                            ChatView(thread: t, otherProfile: other)
                                        } label: {
                                            InboxRow(
                                                profile: other,
                                                subtitle: lastMessageText(threadId: t.id),
                                                unreadCount: unreadCount(threadId: t.id)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func otherProfile(for thread: ChatThread) -> Profile? {
        profiles.first(where: { $0.id == thread.otherProfileId })
    }

    private func lastMessageText(threadId: String) -> String {
        let last = messages
            .filter { $0.threadId == threadId }
            .sorted { $0.createdAt > $1.createdAt }
            .first

        return last?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? (last?.text ?? "")
        : "Sohbete devam et"
    }

    private func unreadCount(threadId: String) -> Int {
        guard let me = session.currentProfile else { return 0 }
        return messages.filter {
            $0.threadId == threadId &&
            $0.isRead == false &&
            $0.senderProfileId != me.id   // ✅ karşı taraftan gelen okunmamışlar
        }.count
    }
}

private struct InboxRow: View {
    let profile: Profile
    let subtitle: String
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.main)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 9)
                    .background(Capsule().fill(AppTheme.accent))
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.text.opacity(0.3))
            }
        }
        .padding(12)
        .background(AppTheme.text.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private var avatar: some View {
        Group {
            if let d = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(Circle())
    }
}
