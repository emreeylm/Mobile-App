import SwiftUI
import SwiftData

struct ChatView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var thread: ChatThread?
    let otherProfile: Profile

    init(thread: ChatThread? = nil, otherProfile: Profile) {
        _thread = State(initialValue: thread)
        self.otherProfile = otherProfile
    }

    @Query private var allMessages: [ChatMessage]
    @State private var text: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                customHeader
                
                Divider().background(AppTheme.text.opacity(0.1))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Date Tag Example
                            dateTag("Bugün")
                            
                            ForEach(messagesForThread, id: \.id) { msg in
                                bubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: messagesForThread.count) { _, _ in
                        scrollLast(proxy)
                    }
                    .onAppear {
                        scrollLast(proxy)
                    }
                }

                // Composer
                composerArea
            }
            .padding(.bottom, 100) // ✅ Push above the floaty tab bar
        }
        .navigationBarHidden(true)
    }

    // MARK: - Components

    private var customHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
            }
            
            // Avatar & Name -> Navigation to Profile
            NavigationLink {
                ProfilePreviewView(profile: otherProfile)
            } label: {
                HStack(spacing: 10) {
                    if let data = otherProfile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                       let ui = UIImage(data: data) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(AppTheme.background, lineWidth: 1.5))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(otherProfile.firstName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                        Text("Çevrimiçi")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Icons
            HStack(spacing: 20) {
                Menu {
                    Button(role: .destructive) {
                        unmatchAction()
                    } label: {
                        Label("Eşleşmeyi Bitir", systemImage: "person.fill.xmark")
                    }
                    
                    Button(role: .destructive) {
                        blockAction()
                    } label: {
                        Label("Engelle", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(AppTheme.text.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.background)
    }

    private var composerArea: some View {
        VStack(spacing: 0) {
            Divider().background(AppTheme.text.opacity(0.05))
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.text.opacity(0.6))
                }
                
                // Input Field
                HStack {
                    TextField("", text: $text, prompt: Text("Mesaj yaz...").foregroundColor(AppTheme.text.opacity(0.3)), axis: .vertical)
                        .lineLimit(1...5)
                        .foregroundColor(AppTheme.text)
                        .padding(.vertical, 10)
                        .padding(.leading, 16)
                    
                    Button(action: {
                        send()
                    }) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.text.opacity(0.3))
                    }
                    .padding(.trailing, 12)
                }
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                
                // Mic or Send
                Button(action: {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Mic trigger
                    } else {
                        send()
                    }
                }) {
                    Image(systemName: text.isEmpty ? "mic.fill" : "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.text.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.text.opacity(0.02))
            .overlay(Divider(), alignment: .top)
        }
    }

    private func dateTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.text.opacity(0.5))
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(AppTheme.text.opacity(0.05))
            .clipShape(Capsule())
    }

    // MARK: - Bubble

    private func bubble(_ msg: ChatMessage) -> some View {
        let isMe = msg.senderProfileId == session.currentProfile?.id

        return HStack(alignment: .bottom) {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.text)
                    .font(.system(size: 16))
                    .foregroundStyle(isMe ? AppTheme.main : AppTheme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isMe ? AppTheme.accent : AppTheme.text.opacity(0.05)
                    )
                    .clipShape(ChatBubbleShape(isMe: isMe))
                
                HStack(spacing: 4) {
                    Text(timeText(msg.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                    
                    if isMe {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    // MARK: - Logic

    private var messagesForThread: [ChatMessage] {
        guard let tid = thread?.id else { return [] }
        return allMessages
            .filter { $0.threadId == tid }
            .sorted(by: { $0.createdAt < $1.createdAt })
    }

    private func scrollLast(_ proxy: ScrollViewProxy) {
        if let last = messagesForThread.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func send() {
        guard let me = session.currentProfile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Create thread if it doesn't exist (First message)
        let activeThread: ChatThread
        if let existing = thread {
            activeThread = existing
        } else {
            let newThread = ChatThread(myProfileId: me.id, otherProfileId: otherProfile.id)
            modelContext.insert(newThread)
            self.thread = newThread
            activeThread = newThread
        }

        let msg = ChatMessage(
            threadId: activeThread.id,
            senderProfileId: me.id,
            text: trimmed
        )

        modelContext.insert(msg)
        activeThread.updatedAt = .now
        try? modelContext.save()
        text = ""
    }

    private func unmatchAction() {
        // Handle unmatch logic: Delete the thread and its messages
        if let t = thread {
            modelContext.delete(t)
            try? modelContext.save()
        }
        dismiss()
    }

    private func blockAction() {
        // Handle block logic: Delete the thread and its messages
        if let t = thread {
            modelContext.delete(t)
            try? modelContext.save()
        }
        dismiss()
    }
}

struct ChatBubbleShape: Shape {
    var isMe: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 20
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isMe 
                ? [.topLeft, .topRight, .bottomLeft] 
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
