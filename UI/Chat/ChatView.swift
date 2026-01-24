import SwiftUI
import SwiftData

struct ChatView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    let thread: ChatThread
    let otherProfile: Profile

    @Query private var allMessages: [ChatMessage]
    @State private var text: String = ""

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header (Inline navigation title handled by OS, but we can customize if needed)
                // For consistency with other screens, let's keep it simple or add a custom bar
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messagesForThread, id: \.id) { msg in
                                bubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: messagesForThread.count) { _, _ in
                        if let last = messagesForThread.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messagesForThread.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                // Composer
                HStack(spacing: 12) {
                    TextField("", text: $text, prompt: Text("Mesaj yaz...").foregroundColor(AppTheme.text.opacity(0.3)), axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundColor(AppTheme.text)
                        .background(AppTheme.text.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))

                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .shadow(color: AppTheme.accent.opacity(0.2), radius: 8)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(AppTheme.main.opacity(0.95))
                .overlay(VStack { Divider().background(AppTheme.text.opacity(0.1)); Spacer() })
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    if let data = otherProfile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(AppTheme.text.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 14)).foregroundColor(AppTheme.text.opacity(0.4)))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(otherProfile.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.text)
                        Text("Çevrimiçi")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var messagesForThread: [ChatMessage] {
        allMessages
            .filter { $0.threadId == thread.id }
            .sorted(by: { $0.createdAt < $1.createdAt })
    }

    // MARK: - UI

    private func bubble(_ msg: ChatMessage) -> some View {
        let isMe = msg.senderProfileId == session.currentProfile?.id

        return HStack {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                Text(msg.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isMe ? AppTheme.main : AppTheme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isMe ? AppTheme.accent : AppTheme.text.opacity(0.08)
                    )
                    .clipShape(ChatBubbleShape(isMe: isMe))
                    .shadow(color: isMe ? AppTheme.accent.opacity(0.1) : .clear, radius: 5, y: 3)

                Text(timeText(msg.createdAt))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.text.opacity(0.3))
                    .padding(isMe ? .trailing : .leading, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    private func timeText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "Dün"
        } else {
            let f = DateFormatter()
            f.dateFormat = "dd.MM.yyyy"
            return f.string(from: date)
        }
    }

    // MARK: - Actions

    private func send() {
        guard let me = session.currentProfile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let msg = ChatMessage(
            threadId: thread.id,
            senderProfileId: me.id,
            text: trimmed
        )

        modelContext.insert(msg)

        thread.updatedAt = .now

        try? modelContext.save()
        text = ""
    }
}

struct ChatBubbleShape: Shape {
    var isMe: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isMe ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}
