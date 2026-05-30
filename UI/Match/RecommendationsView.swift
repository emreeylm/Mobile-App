import SwiftUI
import SwiftData
import CoreLocation

private extension CGFloat {
    var safeNonNegative: CGFloat {
        if self.isFinite == false { return 0 }
        return Swift.max(0, self)   // ✅ Swift.max
    }
    func clamped(_ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minV), maxV) // ✅ Swift.min/max
    }
}

struct RecommendationsView: View {

    @AppStorage("pref.gender") private var prefGender: String = "Herkes"
    @AppStorage("pref.minAge") private var prefMinAge: Int = 18
    @AppStorage("pref.maxAge") private var prefMaxAge: Int = 35
    @AppStorage("pref.distanceKm") private var prefDistanceKm: Int = 25
    @AppStorage("pref.minBoy") private var prefMinBoy: Int = 140
    @AppStorage("pref.maxBoy") private var prefMaxBoy: Int = 220

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @Query private var likes: [LikeEdge]
    @Query private var matches: [Match]
    @ObservedObject private var adManager: AdManager = AdManager.shared

    @State private var deck: [Profile] = []
    @State private var isReady = false
    @State private var dragProgress: CGFloat = 0

    // Recovery / Action States
    @State private var lastSwipedProfile: Profile? = nil
    @State private var isRewinding = false
    @State private var showSwipeLimitPaywall = false
    @State private var showPremiumPaywall = false
    @State private var isFetchingBackend = false
    @State private var networkErrorMessage: String? = nil

    // Superlike mesaj sheet
    @State private var showSuperlikeSheet = false
    @State private var superlikeMessage    = ""

    // Eşleşme kutlama
    @State private var matchedProfile: Profile? = nil

    var body: some View {
        VStack(spacing: 0) { // ✅ No vertical spacing
            // Üstteki Geri Al butonu kaldırıldı, karta taşındı
            Color.clear.frame(height: 0)



            GeometryReader { geo in
                let w = geo.size.width.safeNonNegative
                let h = geo.size.height.safeNonNegative
                
                // Available dynamic space
                let availableW = w.safeNonNegative // ✅ Full width, no side gaps
                let topInset: CGFloat = 0 // ✅ Start card immediately
                let bottomInset: CGFloat = 80 // ✅ Hafifçe küçültüldü (Daha dengeli görünüm)
                let availableH = (h - topInset - bottomInset).safeNonNegative
                
                // 9:16 Logic
                // 1. Calculate ideal height based on width
                let idealH = availableW * (16.0 / 9.0)
                
                // 2. Clamp height to available height
                let finalH = min(idealH, availableH)
                
                // 3. Recalculate width based on constrained height
                let finalW = finalH * (9.0 / 16.0)
                
                let cardW = finalW // ✅ Use calculated width
                let cardH = finalH // ✅ Use calculated height

                ZStack(alignment: .top) {
                    if isReady == false {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        if deck.isEmpty && isFetchingBackend {
                            loadingState
                                .frame(width: cardW, height: cardH)
                                .padding(.top, topInset)
                        } else if deck.isEmpty {
                            emptyState
                                .frame(width: cardW, height: cardH)
                                .padding(.top, topInset)
                        } else {
                            // Stable ID-based rendering for top 2 cards to prevent flickering
                            let visibleCards = Array(deck.prefix(2))
                            
                            ForEach(visibleCards.reversed(), id: \.id) { profile in
                                let isTop = profile.id == deck.first?.id
                                
                                if isTop {
                                    SwipeableRecommendationCard(
                                        profile: profile,
                                        width: cardW,
                                        height: cardH,
                                        onDrag: { progress in
                                            dragProgress = progress
                                        },
                                        onSuperlike: {
                                            superlikeAction()
                                        },
                                        onRewind: {
                                            rewind()
                                        },
                                        isRewindEnabled: lastSwipedProfile != nil,
                                        onSwipe: { liked in
                                            handleSwipe(liked: liked)
                                        }
                                    )
                                    .frame(width: cardW, height: cardH)
                                    .padding(.top, topInset)
                                    .zIndex(1) // Always on top
                                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9), value: deck.first?.id)
                                    .drawingGroup()
                                } else {
                                    // Arka kart: üst kart kaydırıldıkça yukarı yükselir ve büyür
                                    let easedProgress = dragProgress * dragProgress * (3 - 2 * dragProgress) // smoothstep
                                    RecommendationCard(profile: profile)
                                        .frame(width: cardW, height: cardH)
                                        .scaleEffect(0.94 + (0.06 * easedProgress))
                                        .opacity(0.7 + (0.3 * easedProgress))
                                        .offset(y: 12 - (12 * easedProgress))
                                        .allowsHitTesting(false)
                                        .padding(.top, topInset)
                                        .zIndex(0)
                                        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.78), value: dragProgress)
                                }
                            }
                        }
                    }
                }
                .frame(width: w, height: h)
                .offset(y: -40) // ✅ Kartlar biraz daha yukarı alındı
                .animation(.none, value: dragProgress) // ✅ Drag sırasında ana ZStack animasyonunu engelle
            }
        }
        .overlay {
            // Swipe limit overlay
            if showSwipeLimitPaywall {
                swipeLimitOverlay
            }

            // Eşleşme kutlama tam ekran overlay
            if let matched = matchedProfile {
                MatchCelebrationView(
                    profile: matched,
                    myProfile: session.currentProfile,
                    onSendMessage: {
                        withAnimation { matchedProfile = nil }
                        // Tab değişimi parent'ta yönetilmeli; burada sadece overlay kapat
                    },
                    onContinue: {
                        withAnimation { matchedProfile = nil }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $showPremiumPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showSuperlikeSheet) {
            SuperlikeMessageSheet(
                message: $superlikeMessage,
                isPresented: $showSuperlikeSheet,
                onConfirm: { msg in
                    confirmSuperlike(message: msg)
                }
            )
        }
        .alert("Bağlantı Hatası", isPresented: Binding(
            get: { networkErrorMessage != nil },
            set: { if !$0 { networkErrorMessage = nil } }
        )) {
            Button("Tamam") { networkErrorMessage = nil }
            Button("Tekrar Dene") { Task { await fetchBackendProfiles() } }
        } message: {
            Text(networkErrorMessage ?? "")
        }
        .onAppear {
            buildDeck(force: true)
            Task { await fetchBackendProfiles() }
        }
        .onChange(of: profiles.count) { _, _ in buildDeck(force: true) }
        .onChange(of: prefGender) { _, _ in buildDeck(force: true) }
        .onChange(of: prefMinAge) { _, _ in buildDeck(force: true) }
        .onChange(of: prefMaxAge) { _, _ in buildDeck(force: true) }
        .onChange(of: prefMinBoy) { _, _ in buildDeck(force: true) }
        .onChange(of: prefMaxBoy) { _, _ in buildDeck(force: true) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AppTheme.text.opacity(0.3))
                .padding(.bottom, 4)

            Text("Şimdilik kart yok")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.text)

            Text("Yeni profiller eklenince burada görünecek. Filtrelerini genişletmeyi dene.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
            Button {
                buildDeck(force: true)
                Task { await fetchBackendProfiles() }
            } label: {
                Text("Yenile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.main)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(AppTheme.accent)
            Text("Profiller yükleniyor…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func buildDeck(force: Bool) {
        guard let me = session.currentProfile else {
            isReady = true
            deck = []
            return
        }

        // 1. Get IDs of profiles I've already interacted with (Like or Nope)
        let swipedIds = Set(likes.filter { $0.fromProfileId == me.id }.map { $0.toProfileId })
        let matchedIds = Set(matches.filter { $0.myProfileId == me.id }.map { $0.otherProfileId })
        let excludedIds = swipedIds.union(matchedIds)

        // 2. Filter profiles
        var others = profiles.filter { 
            $0.id != me.id && !excludedIds.contains($0.id)
        }
        
        // 3. Apply Premium Filters
        if subscriptionStore.isPremium {
            others = others.filter { p in
                // Age filter
                guard p.age >= prefMinAge && p.age <= prefMaxAge else { return false }

                // Gender filter
                if prefGender != "Herkes" && p.gender.rawValue != prefGender { return false }

                // Height filter (only when a real range is set, not the full 140-220 default)
                if prefMinBoy > 140 || prefMaxBoy < 220 {
                    let heightInt = Int(p.height.components(separatedBy: " ").first ?? "") ?? 0
                    if heightInt > 0 && (heightInt < prefMinBoy || heightInt > prefMaxBoy) { return false }
                }

                // Note: Distance is not actively calculated since distance math requires coordinate data,
                // but if we had it, we would calculate LocationManager.distance(p.location) <= prefDistanceKm

                return true
            }
        }

        let sorted = others.sorted { a, b in
            let ap = a.photos.count
            let bp = b.photos.count
            if ap != bp { return ap > bp }
            return a.name < b.name
        }

        isReady = true
        deck = sorted
    }

    private func handleSwipe(liked: Bool, isSuperLike: Bool = false, message: String? = nil) {
        guard let me = session.currentProfile, let target = deck.first else { return }

        // Kota yalnızca sağ kaydırma (like/super-like) için uygulanır
        if liked || isSuperLike {
            if !subscriptionStore.consumeSwipe() {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSwipeLimitPaywall = true
                }
                return
            }
        }

        lastSwipedProfile = target

        // Karşılıklı beğeni kontrolü (yerel)
        let mutualLike = likes.first(where: { $0.fromProfileId == target.id && $0.toProfileId == me.id && $0.isLike })

        if liked, let otherLike = mutualLike {
            createMatch(with: target, otherLike: otherLike)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    matchedProfile = target
                }
            }
        } else {
            let edge = LikeEdge(fromProfileId: me.id, toProfileId: target.id, isLike: liked, isSuperLike: isSuperLike)
            modelContext.insert(edge)
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            deck.removeFirst()
            dragProgress = 0
        }
        try? modelContext.save()

        // Backend swipe kaydı (fire-and-forget; demo profillerinde başarısız olabilir)
        let backendId = target.ownerUserId
        Task {
            guard !backendId.isEmpty else { return }
            do {
                let eslesmeOldu: Bool
                if isSuperLike {
                    let resp = try await APIClient.shared.sendVipTicket(toId: backendId, message: message)
                    eslesmeOldu = resp.eslesme_oldu
                } else {
                    let direction = liked ? "like" : "dislike"
                    let resp = try await APIClient.shared.swipe(targetId: backendId, direction: direction)
                    eslesmeOldu = resp.eslesme_oldu
                }
                
                // Backend karşılıklı eşleşmeyi tespit ettiyse ama local'de yoksa oluştur
                if eslesmeOldu, liked {
                    let alreadyMatched = matches.contains { $0.myProfileId == me.id && $0.otherProfileId == target.id }
                    if !alreadyMatched {
                        let m1 = Match(myProfileId: me.id, otherProfileId: target.id)
                        let m2 = Match(myProfileId: target.id, otherProfileId: me.id)
                        let thread = ChatThread(myProfileId: me.id, otherProfileId: target.id)
                        modelContext.insert(m1); modelContext.insert(m2); modelContext.insert(thread)
                        try? modelContext.save()
                        // Yerel eşleşme olmadıysa backend teyit edince kutla
                        if matchedProfile?.id != target.id {
                            await MainActor.run {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    matchedProfile = target
                                }
                            }
                        }
                    }
                }
            } catch let error as APIError {
                if case .httpError(429, _) = error {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSwipeLimitPaywall = true
                    }
                }
            } catch {}
        }
    }
    
    private func createMatch(with other: Profile, otherLike: LikeEdge) {
        guard let me = session.currentProfile else { return }
        
        // 1. Create Match entry for both (though currently Match is simple)
        let m1 = Match(myProfileId: me.id, otherProfileId: other.id)
        let m2 = Match(myProfileId: other.id, otherProfileId: me.id)
        modelContext.insert(m1)
        modelContext.insert(m2)
        
        // 2. Clear the incoming like record
        modelContext.delete(otherLike)
        
        // 3. Create ChatThread
        let thread = ChatThread(myProfileId: me.id, otherProfileId: other.id)
        modelContext.insert(thread)
        
        // (Optional) You could insert a system message here
    }
    
    // MARK: - Action Methods
    
    private func rewind() {
        // Premium gate
        guard subscriptionStore.canRewind else {
            showPremiumPaywall = true
            return
        }
        
        guard let last = lastSwipedProfile, let me = session.currentProfile, !isRewinding else { return }
        
        // 1. Clean up my previous interaction in DB
        let myPreviousLikes = likes.filter { $0.fromProfileId == me.id && $0.toProfileId == last.id }
        for edge in myPreviousLikes {
            modelContext.delete(edge)
        }
        
        // 2. Perform UI Rewind
        isRewinding = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            deck.insert(last, at: 0)
            lastSwipedProfile = nil
        }
        
        try? modelContext.save()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRewinding = false
        }
    }
    
    private func superlikeAction() {
        guard !deck.isEmpty else { return }
        // Önce sheet'i aç; consumeSuperLike ve gönderim onay sonrasına erteleniyor
        superlikeMessage = ""
        showSuperlikeSheet = true
    }

    private func confirmSuperlike(message: String?) {
        guard !deck.isEmpty else { return }
        if !subscriptionStore.consumeSuperLike() {
            showPremiumPaywall = true
            return
        }
        handleSwipe(liked: true, isSuperLike: true, message: message)
    }
    
    private func fetchBackendProfiles() async {
        guard !isFetchingBackend else { return }
        isFetchingBackend = true
        defer { isFetchingBackend = false }
        let loc = LocationManager.shared.lastLocation
        let lat = loc?.coordinate.latitude ?? 0.0
        let lon = loc?.coordinate.longitude ?? 0.0
        let isPremium = subscriptionStore.isPremium
        do {
            let minBoyFilter = (prefMinBoy > 140 || prefMaxBoy < 220) ? prefMinBoy : nil
            let maxBoyFilter = (prefMinBoy > 140 || prefMaxBoy < 220) ? prefMaxBoy : nil
            let resp = try await APIClient.shared.getDiscover(
                lat: lat,
                lon: lon,
                minAge: isPremium ? prefMinAge : nil,
                maxAge: isPremium ? prefMaxAge : nil,
                maxDistanceKm: isPremium ? prefDistanceKm : nil,
                minBoy: isPremium ? minBoyFilter : nil,
                maxBoy: isPremium ? maxBoyFilter : nil
            )
            for user in resp.kullanicilar {
                guard profiles.first(where: { $0.ownerUserId == user.id }) == nil else { continue }
                let bday = Calendar.current.date(byAdding: .year, value: -user.yas, to: .now) ?? .now
                let ortak = user.ortak_medya.prefix(3).joined(separator: ", ")
                let bioText = [user.now_watching, ortak.isEmpty ? nil : "Ortak: \(ortak)"]
                    .compactMap { $0 }.joined(separator: " · ")
                let stub = Profile(
                    ownerUserId: user.id, firstName: user.isim, lastName: "",
                    bio: bioText, gender: .other,
                    lookingForGender: .everyone, birthday: bday,
                    remotePhotoURL: user.foto_url
                )
                modelContext.insert(stub)
            }
            try? modelContext.save()
            buildDeck(force: true)
        } catch {
            networkErrorMessage = error.localizedDescription
        }
    }

    private func grantAdReward() {
        guard adManager.canShowAd else { return }
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }

        // Overlay açık haldeyken reklamı sun — UIKit VC, SwiftUI overlay'in üstünde tam ekran açılır.
        // Overlay, reklam bitince callback içinde kapatılır; önceden kapatmaya gerek yok.
        AdManager.shared.showRewardedAd(from: rootVC) { earned in
            Task { @MainActor in
                withAnimation(.spring(response: 0.3)) {
                    self.showSwipeLimitPaywall = false
                }
                if earned {
                    self.subscriptionStore.addAdBonus()
                }
            }
        }
    }

    // MARK: - Swipe Limit Overlay
    
    private var swipeLimitOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.accent)
                
                Text("Günlük Beğeni Limitin Doldu")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
                
                Text("Free planda günlük \(subscriptionStore.swipeLimit) beğeni hakkın var.\nPremium'a geçerek sınırsız beğeni yap!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Button {
                    withAnimation { showSwipeLimitPaywall = false }
                    showPremiumPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                        Text("Premium'a Geç")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "141417"))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
                }

                Button {
                    // Overlay kapatılmıyor — reklam overlay açıkken gösterilir,
                    // kapanış callback'te yapılır. Zamanlama çakışması önlendi.
                    grantAdReward()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: adManager.canShowAd ? "play.rectangle.fill" : "hourglass")
                            .font(.system(size: 14))
                        Text(adManager.canShowAd ? "Reklam İzle (+5 Hak)" : "Reklam Yükleniyor...")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.text.opacity(adManager.canShowAd ? 0.85 : 0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.text.opacity(0.08))
                    .clipShape(Capsule())
                }
                .disabled(!adManager.canShowAd)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showSwipeLimitPaywall = false
                    }
                } label: {
                    Text("Tamam")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(hex: "202024"))
            )
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Component Views
    
    private func actionButtonsGroup(cardW: CGFloat) -> some View {
        ZStack {
            // Geri (Rewind) - Sol Alt
            HStack {
                actionButton(
                    icon: "arrow.uturn.backward",
                    size: 52,
                    isFilled: false,
                    strokeColor: AppTheme.text.opacity(0.3)
                ) {
                    rewind()
                }
                .disabled(lastSwipedProfile == nil)
                .opacity(lastSwipedProfile == nil ? 0.2 : 1.0)
                .padding(.leading, 24) // Sol butonun yeri sabit
                
                Spacer()
            }
            
            // Superlike kaldırıldı, artık kartın içinde
            HStack {
                Spacer()
            }
        }
        .frame(width: cardW)
    }
    
    private func actionButton(
        icon: String,
        size: CGFloat,
        isFilled: Bool,
        fillColor: Color = .clear,
        strokeColor: Color = .clear,
        iconColor: Color = AppTheme.text.opacity(0.7),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isFilled {
                    Circle()
                        .fill(fillColor)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                } else {
                    Circle()
                        .stroke(strokeColor, lineWidth: 1.5)
                        .frame(width: size, height: size)
                }
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
    }
}

// MARK: - Swipeable Card

private struct SwipeableRecommendationCard: View {

    let profile: Profile
    let width: CGFloat
    let height: CGFloat
    let onDrag: (CGFloat) -> Void
    let onSuperlike: () -> Void
    let onRewind: () -> Void
    let isRewindEnabled: Bool
    let onSwipe: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: CGFloat = 0
    @State private var isLeaving = false
    @State private var hapticFired = false  // eşik geçişinde bir kez titreşim

    /// Mesafe eşiği — bu kadar kaydırınca kart uçar
    private let distanceThreshold: CGFloat = 100
    /// Hız eşiği (puan/sn) — bu hızda kısa kaydırmada da kart uçar
    private let velocityThreshold: CGFloat = 450

    // MARK: - Body

    var body: some View {
        ZStack {
            RecommendationCard(
                profile: profile,
                onSuperlike: onSuperlike,
                onRewind: onRewind,
                isRewindEnabled: isRewindEnabled
            )

            // LIKE / NOPE etiketi — her iki taraf her zaman render edilir, opacity ile gösterilir
            HStack(alignment: .top) {
                tagView(text: "BEĞENDİM", color: .green)
                    .padding(.leading, 20)
                    .padding(.top, 24)
                    .opacity(likeTagOpacity)
                Spacer()
                tagView(text: "GEÇTIM", color: .red)
                    .padding(.trailing, 20)
                    .padding(.top, 24)
                    .opacity(nopeTagOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .offset(x: offset.width, y: offset.height)
        .scaleEffect(1.0 + 0.015 * Swift.min(Swift.abs(offset.width) / distanceThreshold, 1.0))
        .rotationEffect(.degrees(rotation), anchor: UnitPoint(x: 0.5, y: 1.1))
        .drawingGroup()
        .gesture(dragGesture)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isLeaving else { return }

                offset = value.translation

                // Yumuşak rotasyon — daha az döner, daha doğal hissettiri
                let normalised = (offset.width / (width * 0.5)).clamped(-1, 1)
                rotation = Double(normalised * 14)

                // Eşik geçince hafif titreşim (bir kez)
                let crossed = Swift.abs(offset.width) > distanceThreshold
                if crossed && !hapticFired {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    hapticFired = true
                } else if !crossed {
                    hapticFired = false
                }

                onDrag(dragProgress)
            }
            .onEnded { value in
                guard !isLeaving else { return }

                let velX = value.velocity.width
                let dx   = offset.width

                let shouldLike  = dx >  distanceThreshold || (dx >  40 && velX >  velocityThreshold)
                let shouldNope  = dx < -distanceThreshold || (dx < -40 && velX < -velocityThreshold)

                if shouldLike {
                    leave(liked: true,  velocityX: velX)
                } else if shouldNope {
                    leave(liked: false, velocityX: velX)
                } else {
                    snapBack()
                }
            }
    }

    // MARK: - Computed opacity

    private var dragProgress: CGFloat {
        Swift.min(Swift.abs(offset.width) / distanceThreshold, 1.0)
    }

    private var likeTagOpacity: CGFloat {
        guard offset.width > 0 else { return 0 }
        return Swift.min(offset.width / (distanceThreshold * 0.6), 1.0)
    }

    private var nopeTagOpacity: CGFloat {
        guard offset.width < 0 else { return 0 }
        return Swift.min(-offset.width / (distanceThreshold * 0.6), 1.0)
    }

    // MARK: - Animation helpers

    private func snapBack() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.4)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.58, blendDuration: 0)) {
            offset   = .zero
            rotation = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.58)) {
            onDrag(0)
        }
        hapticFired = false
    }

    private func leave(liked: Bool, velocityX: CGFloat) {
        isLeaving = true
        let direction: CGFloat = liked ? 1 : -1

        // Hız etkisi: daha hızlı kaydırma = daha uzağa uçar
        let speed   = Swift.max(Swift.abs(velocityX), 400)
        let exitX   = direction * (width + Swift.min(speed * 0.55, 700))
        // Dikey çıkış: parmak neredeyse oraya doğru — doğal yay etkisi
        let exitY   = offset.height * 2.2

        // Çıkış rotasyonu hafifçe artar ama aşırıya kaçmaz
        let exitRot = rotation + Double(direction * 12)

        // Arka kart geçişini tamamla
        onDrag(1.0)

        // Hıza göre spring hızı: hızlı fırlatma → daha kısa response
        let resp = Swift.max(0.22, 0.38 - Swift.min(Swift.abs(velocityX) / 8000, 0.14))

        withAnimation(.spring(response: resp, dampingFraction: 0.88, blendDuration: 0)) {
            offset   = CGSize(width: exitX, height: exitY)
            rotation = exitRot
        }

        // Haptic: beğenme vs geçme
        let style: UIImpactFeedbackGenerator.FeedbackStyle = liked ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()

        // Swipe aksiyonu tetikle — animasyon yarısında
        let actionDelay = resp * 0.55
        DispatchQueue.main.asyncAfter(deadline: .now() + actionDelay) {
            onSwipe(liked)
        }

        // Durumu sıfırla — kartın ekrandan çıkmasından sonra
        DispatchQueue.main.asyncAfter(deadline: .now() + resp + 0.12) {
            offset    = .zero
            rotation  = 0
            isLeaving = false
            hapticFired = false
            onDrag(0)
        }
    }

    // MARK: - Tag view

    private func tagView(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2.5)
            )
            .rotationEffect(.degrees(text == "BEĞENDİM" ? -8 : 8))
    }
}

// MARK: - Card UI

// MARK: - Card UI

private struct RecommendationCard: View {

    let profile: Profile
    var onSuperlike: (() -> Void)? = nil
    var onRewind: (() -> Void)? = nil
    var isRewindEnabled: Bool = false
    
    @EnvironmentObject var session: SessionStore
    
    // ✅ Performance: Cache these values instead of calculating every frame
    @State private var matchScore: Int = 0
    @State private var matchSummary: String = ""

    var body: some View {
        ZStack {
            // 1. Card Container Background (Fixed/Solid Frame)
            AppTheme.surface
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(LinearGradient(colors: [AppTheme.text.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )

            // 2. Content Stack (Image + Info)
            VStack(spacing: 0) {
                
                // Image Section (Inside the frame)
                GeometryReader { geo in
                    imageArea
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(alignment: .bottom) {
                            HStack {
                                // Rewind Button (Left)
                                if isRewindEnabled, let onRewind = onRewind {
                                    Button(action: onRewind) {
                                        ZStack {
                                            Circle()
                                                .fill(AppTheme.surface.opacity(0.9))
                                                .frame(width: 44, height: 44)
                                                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                                            
                                            Image(systemName: "arrow.uturn.backward")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(AppTheme.text.opacity(0.8))
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Superlike Button (Right)
                                if let onSuperlike = onSuperlike {
                                    Button(action: onSuperlike) {
                                        ZStack {
                                            Circle()
                                                .fill(AppTheme.surface.opacity(0.9))
                                                .frame(width: 44, height: 44)
                                                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                                            
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                        }
                }
                .padding(4) // ✅ Further reduced inner image padding
                .frame(maxHeight: .infinity) // Image takes mostly all space
                
                // Info Section (Bottom of Container)
                VStack(alignment: .leading, spacing: 6) {
                    NavigationLink {
                        ProfilePreviewView(profile: profile)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(profile.name)
                                .modernFont(.title, weight: .heavy)
                                .foregroundStyle(AppTheme.text)
                            
                            Text("\(profile.age)")
                                .modernFont(.title3, weight: .semibold)
                                .foregroundStyle(AppTheme.text.opacity(0.6))
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text(matchSummary)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.text.opacity(0.8))
                    
                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
                .padding(.top, 2)
            }
            
            // 3. Match Badge (Overlay on Container Top Right)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Text("%\(matchScore)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                        Text("UYUM")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AppTheme.accent.opacity(0.8))
                    }
                    .padding(10)
                    .background(AppTheme.main.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.5), lineWidth: 2))
                    .shadow(color: AppTheme.accent.opacity(0.2), radius: 5)
                }
                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            // ✅ Only calculate once when the card appears
            matchScore = MatchingService.calculateMatchScore(user: session.currentProfile ?? profile, candidate: profile)
            matchSummary = MatchingService.getCommonSummary(user: session.currentProfile ?? profile, candidate: profile)
        }
    }
    
    private func calculateScore() -> Int {
        guard let me = session.currentProfile else { return 0 }
        return MatchingService.calculateMatchScore(user: me, candidate: profile)
    }
    
    private func calculateSummary() -> String {
        guard let me = session.currentProfile else { return "" }
        return MatchingService.getCommonSummary(user: me, candidate: profile)
    }

    private var imageArea: some View {
        Group {
            if let data = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    // .clipped() is handled by parent clipShape now
            } else {
                ZStack {
                    AppTheme.primaryGradient.opacity(0.1)
                    Image(systemName: profile.avatarSymbol)
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }
        }
    }
}

// MARK: - RecommendationCard Custom Style

extension RecommendationCard {
    // Custom gradient overlay for better readability
    var gradientOverlay: some View {
        LinearGradient(
            colors: [
                .black.opacity(0),
                .black.opacity(0.1),
                .black.opacity(0.4),
                .black.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// Re-defining body for RecommendationCard to use new styles
extension RecommendationCard {
    /* Since we cannot easily extend body in extension without modifying the original struct,
       the layout logic is handled directly in the RecommendationCard's main definition.
    */
}

// MARK: - Superlike Message Sheet

private struct SuperlikeMessageSheet: View {
    @Binding var message: String
    @Binding var isPresented: Bool
    let onConfirm: (String?) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    // İkon
                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.accent)

                    // Başlık + açıklama
                    VStack(spacing: 8) {
                        Text("Superlike Gönder")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)

                        Text("İsteğe bağlı bir mesaj ekleyebilirsin")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.text.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }

                    // Mesaj alanı (opsiyonel)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(height: 120)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.text.opacity(0.05))
                            .foregroundStyle(AppTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
                            )

                        if message.isEmpty {
                            Text("Mesajını yaz… (zorunlu değil)")
                                .foregroundStyle(AppTheme.text.opacity(0.3))
                                .font(.system(size: 15))
                                .padding(.top, 20)
                                .padding(.leading, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    // Gönder butonu
                    Button {
                        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        isPresented = false
                        onConfirm(trimmed.isEmpty ? nil : trimmed)
                    } label: {
                        Text("Gönder")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "141417"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Superlike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { isPresented = false }
                        .foregroundStyle(AppTheme.text)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
