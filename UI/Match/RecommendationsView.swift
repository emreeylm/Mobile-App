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
    @Query private var profiles: [Profile]

    @State private var deck: [Profile] = []
    @State private var isReady = false
    @State private var dragProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) { // ✅ No vertical spacing




            GeometryReader { geo in
                let w = geo.size.width.safeNonNegative
                let h = geo.size.height.safeNonNegative
                
                // Available dynamic space
                let availableW = w.safeNonNegative // ✅ Full width, no side gaps
                let topInset: CGFloat = 0 // ✅ Start card immediately
                let bottomInset: CGFloat = 130 // ✅ Lifted to shift card higher
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
                            if deck.count >= 2 {
                                RecommendationCard(profile: deck[1])
                                    .frame(width: cardW, height: cardH)
                                    .scaleEffect(0.96 + (0.04 * dragProgress)) // ✅ Parallax scale
                                    .opacity(0.85 + (0.15 * dragProgress)) // ✅ Parallax opacity
                                    .offset(y: 8 - (8 * dragProgress)) // ✅ Parallax offset
                                    .allowsHitTesting(false)
                                    .padding(.top, topInset) // ✅ Push down
                                    .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragProgress)
                            }

                            SwipeableRecommendationCard(
                                profile: deck[0],
                                width: cardW,
                                height: cardH,
                                onDrag: { progress in
                                    dragProgress = progress
                                }
                            ) { liked in
                                handleSwipe(liked: liked)
                            }
                            .frame(width: cardW, height: cardH)
                            .padding(.top, topInset) // ✅ Push down
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: deck.first?.id)
                        }
                    }
                }
                .frame(width: w, height: h)
                .offset(y: -40) // ✅ Shift whole stack up without resizing
            }
            .padding(.bottom, 0) // ✅ Removed extra bottom gap
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

    private func handleSwipe(liked: Bool) {
        guard deck.isEmpty == false else { return }

        // ✅ withAnimation “unused” uyarısı: sonucu kullanmıyoruz, zaten statement olarak yeterli
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            deck.removeFirst()
            dragProgress = 0
        }
    }
}

// MARK: - Swipeable Card

private struct SwipeableRecommendationCard: View {

    let profile: Profile
    let width: CGFloat
    let height: CGFloat
    let onDrag: (CGFloat) -> Void
    let onSwipe: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var isLeaving = false

    private let threshold: CGFloat = 120

    var body: some View {
        ZStack {
            RecommendationCard(profile: profile)

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
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isLeaving == false else { return }
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                        offset = value.translation
                        rotation = (offset.width / 15).clamped(-14, 14)
                        
                        // Subtle scaling while dragging
                        let progress = min(abs(offset.width) / threshold, 1.0)
                        scale = 1.0 - (progress * 0.05)
                        onDrag(progress)
                    }
                }
                .onEnded { _ in
                    guard isLeaving == false else { return }

                    if offset.width > threshold {
                        leave(liked: true)
                    } else if offset.width < -threshold {
                        leave(liked: false)
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
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

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
    @EnvironmentObject var session: SessionStore

    var body: some View {
        let matchScore = calculateScore()
        let summary = calculateSummary()
        
        return ZStack {
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
                }
                .padding(4) // ✅ Further reduced inner image padding
                .frame(maxHeight: .infinity) // Image takes mostly all space
                
                // Info Section (Bottom of Container)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(profile.name)
                            .modernFont(.title, weight: .heavy)
                            .foregroundStyle(AppTheme.text)
                        
                        Text("\(profile.age)")
                            .modernFont(.title3, weight: .semibold)
                            .foregroundStyle(AppTheme.text.opacity(0.6))
                        
                        Spacer()
                    }
                    
                    Text(summary)
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
