import SwiftUI
import SwiftData

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

    @EnvironmentObject var session: SessionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]

    @State private var deck: [Profile] = []
    @State private var isReady = false
    @State private var dragProgress: CGFloat = 0
    
    // Recovery / Action States
    @State private var lastSwipedProfile: Profile? = nil
    @State private var isRewinding = false

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
                        if deck.isEmpty {
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
                                    RecommendationCard(profile: profile)
                                        .frame(width: cardW, height: cardH)
                                        .scaleEffect(0.96 + (0.04 * dragProgress))
                                        .opacity(0.85 + (0.15 * dragProgress))
                                        .offset(y: 8 - (8 * dragProgress))
                                        .allowsHitTesting(false)
                                        .padding(.top, topInset)
                                        .zIndex(0) // Background card
                                        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragProgress)
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
        .onAppear { buildDeck(force: true) }
        .onChange(of: profiles.count) { _, _ in
            buildDeck(force: true)
        }
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

    private func buildDeck(force: Bool) {
        guard let me = session.currentProfile else {
            isReady = true
            deck = []
            return
        }

        let others = profiles.filter { $0.id != me.id }

        let sorted = others.sorted { a, b in
            let ap = a.photos.count
            let bp = b.photos.count
            if ap != bp { return ap > bp }
            return a.name < b.name
        }

        isReady = true
        deck = sorted
    }

    private func handleSwipe(liked: Bool, isSuperLike: Bool = false) {
        guard let me = session.currentProfile, let target = deck.first else { return }
        
        // Save for rewind
        lastSwipedProfile = target

        // Persist the like
        let edge = LikeEdge(fromProfileId: me.id, toProfileId: target.id, isLike: liked, isSuperLike: isSuperLike)
        modelContext.insert(edge)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            deck.removeFirst()
            dragProgress = 0
        }
    }
    
    // MARK: - Action Methods
    
    private func rewind() {
        guard let last = lastSwipedProfile, !isRewinding else { return }
        
        isRewinding = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            deck.insert(last, at: 0)
            lastSwipedProfile = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRewinding = false
        }
    }
    
    private func superlikeAction() {
        guard !deck.isEmpty else { return }
        handleSwipe(liked: true, isSuperLike: true)
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
    @State private var scale: CGFloat = 1.0
    @State private var isLeaving = false

    private let threshold: CGFloat = 120

    var body: some View {
        ZStack {
            RecommendationCard(
                profile: profile,
                onSuperlike: onSuperlike,
                onRewind: onRewind,
                isRewindEnabled: isRewindEnabled
            )

            HStack {
                if offset.width > 10 {
                    tagView(text: "LIKE")
                        .padding(.leading, 18)
                        .padding(.top, 18)
                    Spacer()
                } else if offset.width < -10 {
                    Spacer()
                    tagView(text: "NOPE")
                        .padding(.trailing, 18)
                        .padding(.top, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(tagOpacity)
        }
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(rotation)))
        .scaleEffect(scale)
        .drawingGroup() // ✅ GPU acceleration for smooth dragging
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isLeaving == false else { return }
                    // ✅ Removed withAnimation for instant feedback during drag
                    offset = value.translation
                    rotation = (offset.width / 15).clamped(-14, 14)
                    
                    // Subtle scaling while dragging
                    let progress = min(abs(offset.width) / threshold, 1.0)
                    scale = 1.0 - (progress * 0.05)
                    onDrag(progress)
                }
                .onEnded { _ in
                    guard isLeaving == false else { return }

                    if offset.width > threshold {
                        leave(liked: true)
                    } else if offset.width < -threshold {
                        leave(liked: false)
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            offset = .zero
                            rotation = 0
                            scale = 1.0
                            onDrag(0)
                        }
                    }
                }
        )
    }

    private var tagOpacity: CGFloat {
        let v = (Swift.abs(offset.width) / 120).safeNonNegative
        return Swift.min(Swift.max(v, 0), 1)
    }

    private func leave(liked: Bool) {
        isLeaving = true
        let direction: CGFloat = liked ? 1 : -1

        onDrag(1.0) // Ensure background card completes transition

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            offset = CGSize(width: direction * (width + 300), height: 80 * direction)
            rotation = direction * 25
            scale = 0.8 // Shrink slightly as it leaves
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(liked)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            offset = .zero
            rotation = 0
            scale = 1.0
            isLeaving = false
            onDrag(0)
        }
    }

    private func tagView(text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(text == "LIKE" ? Color.green : Color.red, lineWidth: 3)
            )
            .scaleEffect(1.0 + (tagOpacity * 0.2))
            .rotationEffect(.degrees(text == "LIKE" ? -10 : 10))
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
