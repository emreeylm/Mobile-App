import SwiftUI

// MARK: - MatchCelebrationView
/// Tam ekran eşleşme kutlama ekranı. MatchToast'ın yerini alır.

struct MatchCelebrationView: View {
    let profile: Profile
    let myProfile: Profile?
    let onSendMessage: () -> Void
    let onContinue: () -> Void

    // Animation states
    @State private var showContent = false
    @State private var showProfiles = false
    @State private var showButtons = false
    @State private var particles: [Particle] = []
    @State private var heartScale: CGFloat = 0

    var body: some View {
        ZStack {
            // Background blur overlay
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { /* consume tap */ }

            // Confetti particles
            ForEach(particles) { p in
                ParticleView(particle: p)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // "It's a Match!" header
                VStack(spacing: 6) {
                    Text("Eşleşme!")
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent, Color.pink, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 16, x: 0, y: 6)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1 : 0)

                    Text("\(profile.firstName) ile ortak zevkleriniz var 🎬")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .scaleEffect(showContent ? 1.0 : 0.7)
                        .opacity(showContent ? 1 : 0)
                }
                .padding(.bottom, 40)

                // Profile avatars with heart
                HStack(spacing: 0) {
                    // My avatar
                    avatarView(profile: myProfile, isMe: true)
                        .offset(x: showProfiles ? 0 : -120)
                        .opacity(showProfiles ? 1 : 0)

                    // Heart in middle
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.pink, Color.red.opacity(0.8)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 26
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: .pink.opacity(0.5), radius: 10)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(heartScale)
                    .zIndex(1)
                    .offset(x: 0)

                    // Their avatar
                    avatarView(profile: profile, isMe: false)
                        .offset(x: showProfiles ? 0 : 120)
                        .opacity(showProfiles ? 1 : 0)
                }
                .padding(.bottom, 40)

                // Ortak medya pill
                if !profile.watchedTitles.isEmpty {
                    let shared = profile.watchedTitles.prefix(2).joined(separator: " · ")
                    HStack(spacing: 6) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 13))
                        Text(shared)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.bottom, 36)
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 12)
                }

                // Action buttons
                VStack(spacing: 14) {
                    // Mesaj Gönder — primary
                    Button {
                        onSendMessage()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Mesaj Gönder")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.accent, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    }

                    // Devam Et — secondary
                    Button {
                        onContinue()
                    } label: {
                        Text("Devam Et")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 36)
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 20)

                Spacer()
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private func avatarView(profile: Profile?, isMe: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isMe
                            ? [AppTheme.accent, Color.blue.opacity(0.8)]
                            : [Color.pink, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 110)
                .shadow(color: (isMe ? AppTheme.accent : Color.pink).opacity(0.35), radius: 14)

            if let photoData = profile?.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let uiImage = UIImage(data: photoData) {
                // Yerel fotoğraf var → öncelikli kullan
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 106, height: 106)
                    .clipShape(Circle())
            } else if let urlStr = profile?.remotePhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    avatarSymbol(profile: profile, isMe: isMe)
                }
                .frame(width: 106, height: 106)
                .clipShape(Circle())
            } else {
                avatarSymbol(profile: profile, isMe: isMe)
            }

            // Ring
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 3)
                .frame(width: 110, height: 110)
        }
        .padding(.horizontal, -10)
    }

    @ViewBuilder
    private func avatarSymbol(profile: Profile?, isMe: Bool) -> some View {
        if let sym = profile?.avatarSymbol {
            Image(systemName: sym)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        } else {
            Image(systemName: isMe ? "person.fill" : "person.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        spawnParticles()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
            showContent = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.35)) {
            showProfiles = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.55)) {
            heartScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            showButtons = true
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [AppTheme.accent, .pink, .purple, .yellow, .orange, .mint, .cyan]
        particles = (0..<60).map { i in
            Particle(
                id: i,
                x: CGFloat.random(in: 0.05...0.95),
                startY: CGFloat.random(in: -0.05...0.15),
                endY: CGFloat.random(in: 0.85...1.1),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 5...12),
                delay: Double.random(in: 0...0.8),
                duration: Double.random(in: 1.8...3.2),
                rotation: Double.random(in: 0...360),
                shape: Particle.Shape.allCases.randomElement()!
            )
        }
    }
}

// MARK: - Particle System

struct Particle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let shape: Shape

    enum Shape: CaseIterable { case circle, rect, star }
}

struct ParticleView: View {
    let particle: Particle
    @State private var active = false
    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            particleView
                .frame(width: particle.size, height: particle.size)
                .rotationEffect(.degrees(active ? particle.rotation + 360 : particle.rotation))
                .position(
                    x: particle.x * w,
                    y: active ? particle.endY * h : particle.startY * h
                )
                .opacity(opacity)
                .onAppear {
                    withAnimation(
                        .easeIn(duration: particle.duration)
                        .delay(particle.delay)
                    ) {
                        active = true
                    }
                    withAnimation(
                        .easeOut(duration: 0.4)
                        .delay(particle.delay)
                    ) {
                        opacity = 1
                    }
                    withAnimation(
                        .easeIn(duration: 0.6)
                        .delay(particle.delay + particle.duration - 0.6)
                    ) {
                        opacity = 0
                    }
                }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var particleView: some View {
        switch particle.shape {
        case .circle:
            Circle().fill(particle.color)
        case .rect:
            RoundedRectangle(cornerRadius: 2).fill(particle.color)
        case .star:
            Circle().fill(particle.color)
        }
    }
}

// MARK: - Profile extension helper

private extension Profile {
    var watchedTitles: [String] {
        // bio'dan "Ortak: X, Y" kısmını parse et
        if let range = bio.range(of: "Ortak: ") {
            let after = String(bio[range.upperBound...])
            return after.components(separatedBy: ", ").filter { !$0.isEmpty }
        }
        return []
    }
}
