import Foundation
import SwiftData
import Combine
import os

/// Backend WebSocket chat bağlantısını yönetir.
///
/// `connect(...)` çağrısı ile bağlantı kurulur. Gelen mesajlar ve tarihsel
/// mesajlar otomatik olarak SwiftData'ya kaydedilir. Duplicate kontrolü
/// `remoteIdStr` alanı ile yapılır.
@MainActor
final class ChatWebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {

    enum ConnectionState {
        case disconnected, connecting, connected

        var dotColor: String {
            switch self {
            case .connected:    return "green"
            case .connecting:   return "yellow"
            case .disconnected: return "gray"
            }
        }
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var partnerIsTyping: Bool = false
    /// Partner'ın okuduğunu onayladığı son mesajın remote ID'si
    @Published var lastReadByPartner: Int = 0

    private var task: URLSessionWebSocketTask?
    private var typingResetTask: Task<Void, Never>?

    // Backend UUID (WS endpoint'inde kullanılır)
    private let otherBackendUserId: String

    // Mesaj eşleştirme için lokal ID'ler
    private var myBackendUserId: String?
    private var myProfileId: String?
    private var otherProfileId: String?
    private var activeThreadId: String?

    private var modelContext: ModelContext?
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.bingedate", category: "ChatWS")

    // Reconnect
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private var isManualDisconnect = false

    /// Son connect() çağrısının parametreleri — reconnect için saklanır
    private struct ConnectParams {
        let myBackendUserId: String
        let myProfileId: String
        let otherProfileId: String
        let threadId: String
    }
    private var lastConnectParams: ConnectParams?

    init(otherBackendUserId: String) {
        self.otherBackendUserId = otherBackendUserId
        super.init()
    }

    deinit {
        task?.cancel(with: .normalClosure, reason: nil)
    }

    // MARK: - Bağlantı

    func connect(
        modelContext: ModelContext,
        myBackendUserId: String,
        myProfileId: String,
        otherProfileId: String,
        threadId: String
    ) {
        guard connectionState == .disconnected else { return }
        guard !otherBackendUserId.isEmpty else {
            logger.warning("otherBackendUserId boş — WS atlandı (demo profil?)")
            return
        }
        guard let token = keychain.load(for: KeychainManager.accessTokenKey) else {
            logger.warning("Erişim tokenı yok — WS atlandı")
            return
        }

        self.modelContext = modelContext
        self.myBackendUserId = myBackendUserId
        self.myProfileId = myProfileId
        self.otherProfileId = otherProfileId
        self.activeThreadId = threadId
        self.isManualDisconnect = false
        self.lastConnectParams = ConnectParams(
            myBackendUserId: myBackendUserId,
            myProfileId: myProfileId,
            otherProfileId: otherProfileId,
            threadId: threadId
        )

        let wsBase = APIClient.shared.webSocketBaseURL
        guard let url = URL(string: "\(wsBase)/ws/chat/\(otherBackendUserId)") else {
            logger.error("Geçersiz WS URL")
            return
        }

        // Token, URL query'de değil Sec-WebSocket-Protocol header'ında taşınır (log sızıntısını önler)
        var request = URLRequest(url: url)
        request.setValue("bearer.\(token)", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        connectionState = .connecting
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let t = session.webSocketTask(with: request)
        task = t
        t.resume()
        reconnectAttempt = 0  // Başarılı bağlantıda sayacı sıfırla

        scheduleNextReceive()
    }

    func disconnect() {
        isManualDisconnect = true
        reconnectAttempt = 0
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        connectionState = .disconnected
    }

    // MARK: - Gönderme

    func sendRead(lastId: Int) {
        guard connectionState == .connected, let t = task else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["type": "read", "last_id": lastId]),
              let payload = String(data: data, encoding: .utf8) else { return }
        t.send(.string(payload)) { _ in }
    }

    func sendTyping() {
        guard connectionState == .connected, let t = task else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["type": "typing"]),
              let payload = String(data: data, encoding: .utf8) else { return }
        t.send(.string(payload)) { _ in }
    }

    func sendText(_ text: String) {
        guard connectionState == .connected, let t = task else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["text": text]),
              let payload = String(data: data, encoding: .utf8) else { return }
        t.send(.string(payload)) { [weak self] error in
            if let error {
                self?.logger.error("WS gönderme hatası: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Alma döngüsü

    private func scheduleNextReceive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.logger.error("WS alma hatası: \(error.localizedDescription)")
                    self.connectionState = .disconnected
                    self.task = nil
                    self.scheduleReconnect()
                case .success(let message):
                    self.handleRawMessage(message)
                    if self.connectionState == .connected {
                        self.scheduleNextReceive()
                    }
                }
            }
        }
    }

    // MARK: - Mesaj işleme

    private func handleRawMessage(_ raw: URLSessionWebSocketTask.Message) {
        guard case .string(let str) = raw,
              let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ctx = modelContext,
              let tid = activeThreadId
        else { return }

        let msgType  = json["type"]  as? String ?? "message"
        let fromId   = json["from"]  as? String ?? ""
        let text     = json["text"]  as? String ?? ""
        let remoteId = json["id"]    as? Int
        let tarihStr = json["tarih"] as? String ?? ""

        // Okundu bildirimi
        if msgType == "read" {
            if let lastId = json["last_id"] as? Int, lastId > lastReadByPartner {
                lastReadByPartner = lastId
            }
            return
        }

        // Typing indicator — geçici UI state, DB'ye kaydedilmez
        if msgType == "typing" && fromId != myBackendUserId {
            partnerIsTyping = true
            typingResetTask?.cancel()
            typingResetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.partnerIsTyping = false
            }
            return
        }

        guard !text.isEmpty, let rid = remoteId else { return }

        // Gerçek zamanlı kendi yankımızı yoksay (optimistic UI zaten ekledi)
        if msgType == "message" && fromId == myBackendUserId { return }

        // remoteIdStr ile duplicate önle
        let ridStr = "\(rid)"
        let dedupDesc = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.remoteIdStr == ridStr }
        )
        if (try? ctx.fetch(dedupDesc))?.isEmpty == false { return }

        // backend UUID → yerel Profile.id dönüşümü
        let localSenderId: String
        if fromId == myBackendUserId {
            localSenderId = myProfileId ?? fromId
        } else {
            localSenderId = otherProfileId ?? fromId
        }

        let date = parseDate(tarihStr)

        let chatMsg = ChatMessage(threadId: tid, senderProfileId: localSenderId, text: text)
        chatMsg.remoteIdStr = ridStr
        chatMsg.createdAt = date
        ctx.insert(chatMsg)

        // Thread.updatedAt güncelle
        let threadDesc = FetchDescriptor<ChatThread>(
            predicate: #Predicate { $0.id == tid }
        )
        if let thread = try? ctx.fetch(threadDesc).first {
            thread.updatedAt = date
        }

        try? ctx.save()
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard !isManualDisconnect else { return }
        guard reconnectAttempt < maxReconnectAttempts else {
            logger.warning("WS: maksimum reconnect deneme sayısına (\(self.maxReconnectAttempts)) ulaşıldı.")
            return
        }
        let delay = pow(2.0, Double(reconnectAttempt)) // 1, 2, 4, 8, 16 sn
        reconnectAttempt += 1
        logger.info("WS: \(delay)s sonra yeniden bağlanılacak (deneme \(self.reconnectAttempt)/\(self.maxReconnectAttempts))")

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !self.isManualDisconnect, self.connectionState == .disconnected,
                  let p = self.lastConnectParams, let ctx = self.modelContext else { return }
            self.connect(
                modelContext: ctx,
                myBackendUserId: p.myBackendUserId,
                myProfileId: p.myProfileId,
                otherProfileId: p.otherProfileId,
                threadId: p.threadId
            )
        }
    }

    // MARK: - Yardımcı

    private func parseDate(_ str: String) -> Date {
        let withMicros = ISO8601DateFormatter()
        withMicros.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withMicros.date(from: str) { return d }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: str) ?? .now
    }

    // MARK: - URLSessionWebSocketDelegate

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        Task { @MainActor in
            self.connectionState = .connected
            self.logger.info("WS connection established")
        }
    }
}
