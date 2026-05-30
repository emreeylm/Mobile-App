import SwiftUI
import SwiftData
import PhotosUI

struct ChatView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var thread: ChatThread?
    let otherProfile: Profile

    @StateObject private var wsService: ChatWebSocketService

    init(thread: ChatThread? = nil, otherProfile: Profile) {
        _thread = State(initialValue: thread)
        self.otherProfile = otherProfile
        _wsService = StateObject(
            wrappedValue: ChatWebSocketService(otherBackendUserId: otherProfile.ownerUserId)
        )
    }

    @Query private var allMessages: [ChatMessage]
    @State private var text: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @State private var isKeyboardVisible = false
    @State private var actionErrorMessage: String? = nil

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                Divider().background(AppTheme.text.opacity(0.1))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            dateTag("Bugün")

                            ForEach(messagesForThread, id: \.id) { msg in
                                bubble(msg)
                                    .id(msg.id)
                            }

                            if wsService.partnerIsTyping {
                                typingBubble
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: messagesForThread.count) { _, _ in scrollLast(proxy) }
                    .onChange(of: wsService.partnerIsTyping) { _, isTyping in
                        if isTyping { scrollTo(proxy, id: "typing") }
                    }
                    .onAppear { scrollLast(proxy) }
                }

                composerArea
            }
            .padding(.bottom, isKeyboardVisible ? 0 : 100)
        }
        .onAppear {
            connectWS()
            fetchHistoryHTTP()
        }
        .onDisappear { wsService.disconnect() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .navigationBarHidden(true)
        .alert("Hata", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("Tamam") { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    // MARK: - Header

    private var customHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
            }

            NavigationLink {
                ProfilePreviewView(profile: otherProfile)
            } label: {
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        if let data = otherProfile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                           let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(AppTheme.surface)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(AppTheme.text.opacity(0.3))
                                )
                        }

                        connectionDot
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(otherProfile.firstName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                        Text(connectionLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(connectionLabelColor)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Button(role: .destructive) { unmatchAction() } label: {
                    Label("Eşleşmeyi Bitir", systemImage: "person.fill.xmark")
                }
                Button(role: .destructive) { blockAction() } label: {
                    Label("Engelle", systemImage: "hand.raised.fill")
                }
                Menu("Raporla") {
                    Button("Spam") { reportAction(reason: "spam") }
                    Button("Uygunsuz İçerik") { reportAction(reason: "uygunsuz_icerik") }
                    Button("Taciz") { reportAction(reason: "taciz") }
                    Button("Sahte Profil") { reportAction(reason: "sahte_profil") }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.background)
    }

    private var connectionDot: some View {
        Circle()
            .fill(connectionDotColor)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(AppTheme.background, lineWidth: 1.5))
            .padding(2)
    }

    private var connectionDotColor: Color {
        switch wsService.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .disconnected: return .gray
        }
    }

    private var connectionLabel: String {
        switch wsService.connectionState {
        case .connected:    return "Çevrimiçi"
        case .connecting:   return "Bağlanıyor..."
        case .disconnected: return "Çevrimdışı"
        }
    }

    private var connectionLabelColor: Color {
        switch wsService.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .disconnected: return AppTheme.text.opacity(0.4)
        }
    }

    // MARK: - Composer

    private var composerArea: some View {
        VStack(spacing: 0) {
            Divider().background(AppTheme.text.opacity(0.05))

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.text.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            sendPhoto(data)
                        }
                        selectedItem = nil
                    }
                }

                HStack {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text("Mesaj yaz...").foregroundColor(AppTheme.text.opacity(0.3)),
                        axis: .vertical
                    )
                    .lineLimit(1...5)
                    .foregroundColor(AppTheme.text)
                    .padding(.vertical, 10)
                    .padding(.leading, 16)
                    .onChange(of: text) { _, newValue in
                        if !newValue.isEmpty { wsService.sendTyping() }
                    }
                }
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                if !text.isEmpty {
                    Button { send() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.text.opacity(0.6))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.text.opacity(0.02))
            .overlay(Divider(), alignment: .top)
        }
    }

    // MARK: - Date tag

    private func dateTag(_ label: String) -> some View {
        Text(label)
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
                if let data = msg.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(4)
                        .background(isMe ? AppTheme.accent : AppTheme.text.opacity(0.05))
                        .clipShape(ChatBubbleShape(isMe: isMe))
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 16))
                        .foregroundStyle(isMe ? AppTheme.main : AppTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isMe ? AppTheme.accent : AppTheme.text.opacity(0.05))
                        .clipShape(ChatBubbleShape(isMe: isMe))
                }

                HStack(spacing: 4) {
                    Text(timeText(msg.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.text.opacity(0.4))

                    if isMe {
                        Image(systemName: msg.remoteIdStr.isEmpty ? "clock" : "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(msg.remoteIdStr.isEmpty
                                ? AppTheme.text.opacity(0.3)
                                : AppTheme.accent)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    // MARK: - Computed

    private var messagesForThread: [ChatMessage] {
        guard let tid = thread?.id else { return [] }
        return allMessages
            .filter { $0.threadId == tid }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func scrollLast(_ proxy: ScrollViewProxy) {
        if let last = messagesForThread.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private func scrollTo(_ proxy: ScrollViewProxy, id: String) {
        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
    }

    private var typingBubble: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppTheme.text.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .offset(y: -3)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: wsService.partnerIsTyping
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(ChatBubbleShape(isMe: false))

            Spacer(minLength: 60)
        }
        .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Actions

    /// Backend'den geçmiş mesajları HTTP ile çeker, SwiftData'ya merge eder.
    /// WebSocket bağlanmadan önce de mesajların görünmesini sağlar.
    private func fetchHistoryHTTP() {
        guard let me = session.currentProfile else { return }
        let otherUserId = otherProfile.ownerUserId
        guard !otherUserId.isEmpty else { return }

        // Thread yoksa oluştur
        let tid: String
        if let existing = thread {
            tid = existing.id
        } else {
            let newThread = ChatThread(myProfileId: me.id, otherProfileId: otherProfile.id)
            modelContext.insert(newThread)
            try? modelContext.save()
            thread = newThread
            tid = newThread.id
        }

        Task {
            guard let history = try? await APIClient.shared.getChatHistory(otherUserId: otherUserId) else { return }
            await MainActor.run {
                for dto in history.messages {
                    let ridStr = "\(dto.id)"
                    // Duplicate kontrolü
                    let dedupDesc = FetchDescriptor<ChatMessage>(
                        predicate: #Predicate { $0.remoteIdStr == ridStr }
                    )
                    if (try? modelContext.fetch(dedupDesc))?.isEmpty == false { continue }

                    let localSenderId: String
                    if dto.from == me.ownerUserId {
                        localSenderId = me.id
                    } else {
                        localSenderId = otherProfile.id
                    }

                    let msg = ChatMessage(threadId: tid, senderProfileId: localSenderId, text: dto.text)
                    msg.remoteIdStr = ridStr

                    // ISO8601 parse
                    let isoFull = ISO8601DateFormatter()
                    isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let isoBasic = ISO8601DateFormatter()
                    msg.createdAt = isoFull.date(from: dto.tarih) ?? isoBasic.date(from: dto.tarih) ?? .now

                    modelContext.insert(msg)
                }
                try? modelContext.save()
            }
        }
    }

    private func connectWS() {
        guard let me = session.currentProfile else { return }

        // Thread yoksa oluştur
        if thread == nil {
            let newThread = ChatThread(myProfileId: me.id, otherProfileId: otherProfile.id)
            modelContext.insert(newThread)
            try? modelContext.save()
            thread = newThread
        }

        guard let tid = thread?.id else { return }

        wsService.connect(
            modelContext: modelContext,
            myBackendUserId: me.ownerUserId,
            myProfileId: me.id,
            otherProfileId: otherProfile.id,
            threadId: tid
        )
    }

    private func send() {
        guard let me = session.currentProfile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Thread yoksa oluştur
        let activeThread: ChatThread
        if let existing = thread {
            activeThread = existing
        } else {
            let newThread = ChatThread(myProfileId: me.id, otherProfileId: otherProfile.id)
            modelContext.insert(newThread)
            self.thread = newThread
            activeThread = newThread
        }

        // Optimistic UI: SwiftData'ya hemen ekle
        let msg = ChatMessage(threadId: activeThread.id, senderProfileId: me.id, text: trimmed)
        modelContext.insert(msg)
        activeThread.updatedAt = .now
        try? modelContext.save()
        text = ""

        // Backend'e gönder
        wsService.sendText(trimmed)
    }

    private func sendPhoto(_ data: Data) {
        guard let me = session.currentProfile else { return }

        let activeThread: ChatThread
        if let existing = thread {
            activeThread = existing
        } else {
            let newThread = ChatThread(myProfileId: me.id, otherProfileId: otherProfile.id)
            modelContext.insert(newThread)
            self.thread = newThread
            activeThread = newThread
        }

        let msg = ChatMessage(threadId: activeThread.id, senderProfileId: me.id, imageData: data)
        modelContext.insert(msg)
        activeThread.updatedAt = .now
        try? modelContext.save()
    }

    private func unmatchAction() {
        if let t = thread { modelContext.delete(t) }
        try? modelContext.save()
        wsService.disconnect()
        dismiss()
    }

    private func blockAction() {
        let targetId = otherProfile.ownerUserId
        if let t = thread { modelContext.delete(t) }
        try? modelContext.save()
        wsService.disconnect()
        Task {
            do {
                try await APIClient.shared.blockUser(targetId: targetId)
            } catch {
                // Yerel silme yapıldı; backend hatası sessizce loglanır
            }
        }
        dismiss()
    }

    private func reportAction(reason: String) {
        let targetId = otherProfile.ownerUserId
        Task {
            do {
                try await APIClient.shared.reportUser(targetId: targetId, reason: reason)
            } catch {
                actionErrorMessage = "Raporlama gönderilemedi: \(error.localizedDescription)"
            }
        }
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
