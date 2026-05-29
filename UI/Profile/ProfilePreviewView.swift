import SwiftUI
import SwiftData

struct ProfilePreviewView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @Query private var mediaItems: [MediaItem]
    @Query private var profileMedia: [ProfileMedia]

    var profile: Profile? // Optional: show specific profile

    @State private var showAllMovies = false
    @State private var showAllSeries = false
    @State private var showVipSheet = false
    @State private var vipMessage = ""
    @State private var vipSent = false
    @State private var vipError = false
    @State private var showPaywall = false

    private var displayProfile: Profile? {
        profile ?? session.currentProfile
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.background
                .ignoresSafeArea()

            if let p = displayProfile {
                VStack(spacing: 0) {
                    // 1. Fixed Custom Header
                    headerView(isMe: p.id == session.currentProfile?.id)
                        .padding(.horizontal, 24)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 2. Main Profile Image
                            mainImageView(profile: p)
                            
                            // 3. Identity Section
                            identitySection(profile: p)
                            
                            // 4. Info Grid
                            infoGrid(profile: p)
                            
                            // 5. Personal Narrative
                            bioSection(profile: p)
                            
                            // 6. Interests (Genres)
                            interestsSection(profile: p)
                            
                            // 7. My Media (Specific Movies & Series)
                            mediaListSection(profile: p, type: .movie, title: "FİLMLERİM")
                            mediaListSection(profile: p, type: .series, title: "DİZİLERİM")

                            // 8. VIP send button (başkasının profili)
                            if p.id != session.currentProfile?.id {
                                vipSendButton(profile: p)
                            }

                            Spacer(minLength: 120) // Tab bar clearance
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                Text("Profil bulunamadı.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showVipSheet) {
            if let p = displayProfile {
                VIPSendSheet(targetId: p.ownerUserId, message: $vipMessage,
                             isPresented: $showVipSheet, onSent: { vipSent = true })
            }
        }
        .alert("VIP Mesaj Gönderildi", isPresented: $vipSent) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Mesajın karşı tarafa iletildi.")
        }
        .alert("Hata", isPresented: $vipError) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("VIP bilet gönderilemedi. Bilet bakiyeni kontrol et.")
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Components

    private func headerView(isMe: Bool) -> some View {
        HStack {
            if !isMe {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.text)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.text.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            
            Spacer()

            if isMe {
                HStack(spacing: 10) {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.text.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.text.opacity(0.08), lineWidth: 1))
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.text.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.text.opacity(0.08), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private func mainImageView(profile: Profile) -> some View {
        GeometryReader { geo in
            let imageSize = geo.size.width
            ZStack(alignment: .bottomTrailing) {
                if let photoData = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                } else {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(AppTheme.text.opacity(0.05))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(AppTheme.text.opacity(0.2))
                        )
                }
            }
            .frame(width: imageSize, height: imageSize)
        }
        .aspectRatio(1, contentMode: .fit)
    }


    private func identitySection(profile: Profile) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(profile.firstName), \(profile.age)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
            }

            if !profile.nowWatching.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.accent)
                    Text(profile.nowWatching)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.1))
                .clipShape(Capsule())
            }

            if !profile.city.isEmpty {
                HStack(spacing: 6) {
                    Text(profile.city)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.text.opacity(0.6))
                }
            }
        }
    }

    private func infoGrid(profile: Profile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            infoCard(icon: "ruler", value: profile.height, label: "BOY")
            infoCard(icon: "briefcase", value: profile.jobTitle.isEmpty ? "Belirtilmedi" : profile.jobTitle, label: "MESLEK")
            infoCard(icon: "nosign", value: profile.smokingHabit, label: "SİGARA")
        }
    }

    private func infoCard(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.text.opacity(0.08))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value.isEmpty ? "Belirtilmedi" : value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.text.opacity(0.4))
                    .kerning(0.5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(AppTheme.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
        )
    }

    private func bioSection(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KİŞİSEL ANLATIM")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .kerning(1.2)
            
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.text.opacity(0.2))
                
                Text(profile.bio.isEmpty ? "Henüz bir biyografi eklenmedi." : profile.bio)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.text.opacity(0.8))
                    .lineSpacing(6)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.text.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func interestsSection(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("İLGİ ALANLARI")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .kerning(1.2)

            if profile.favoriteMovieGenres.isEmpty {
                Text("Henüz seçilmedi")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.text.opacity(0.3))
            } else {
                FlowLayout(items: profile.favoriteMovieGenres) { genre in
                    Text(genre)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.text)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(AppTheme.text.opacity(0.05))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func mediaListSection(profile: Profile, type: MediaType, title: String) -> some View {
        let ids = Set(profileMedia.filter { $0.profileId == profile.id }.map { $0.mediaId })
        let list = mediaItems
            .filter { $0.type == type && ids.contains($0.id) }
            .sorted { $0.title < $1.title }
        let showAll = type == .movie ? showAllMovies : showAllSeries
        let displayList = showAll ? list : Array(list.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .kerning(1.2)

            if list.isEmpty {
                Text("Henüz eklenmedi")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.text.opacity(0.3))
            } else {
                VStack(spacing: 8) {
                    ForEach(displayList, id: \.id) { item in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.text.opacity(0.05))
                                    .frame(width: 40, height: 60)

                                if let urlString = item.posterURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure(_):
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.text.opacity(0.3))
                                        case .empty:
                                            ProgressView().tint(AppTheme.accent).scaleEffect(0.6)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: 40, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.text.opacity(0.3))
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppTheme.text)
                                Text(type == .movie ? "Film" : "Dizi")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.text.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(AppTheme.text.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.text.opacity(0.05), lineWidth: 1))
                    }
                }

                if list.count > 5 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if type == .movie { showAllMovies.toggle() }
                            else { showAllSeries.toggle() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showAll ? "Daha az göster" : "\(list.count - 5) tane daha")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func vipSendButton(profile: Profile) -> some View {
        Button {
            guard subscriptionStore.consumeSuperLike() else {
                showPaywall = true
                return
            }
            vipMessage = ""
            showVipSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 16))
                Text("VIP Mesaj Gönder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(hex: "141417"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accent)
            .clipShape(Capsule())
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
        }
    }
}

// MARK: - VIP Send Sheet

private struct VIPSendSheet: View {
    let targetId: String
    @Binding var message: String
    @Binding var isPresented: Bool
    let onSent: () -> Void

    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mesajın (opsiyonel)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.text.opacity(0.6))
                        TextEditor(text: $message)
                            .frame(height: 120)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.text.opacity(0.05))
                            .foregroundStyle(AppTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task { await send() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(Color(hex: "141417"))
                            } else {
                                Text("Gönder")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "141417"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                    }
                    .disabled(isSending)
                }
                .padding(24)
            }
            .navigationTitle("VIP Mesaj")
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

    private func send() async {
        isSending = true
        defer { isSending = false }
        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await APIClient.shared.sendVipTicket(toId: targetId, message: msg.isEmpty ? nil : msg)
            isPresented = false
            onSent()
        } catch {
            errorMessage = "VIP bilet gönderilemedi. Bilet bakiyeni kontrol et."
        }
    }
}

// MARK: - Helper Views



#Preview {
    ProfilePreviewView()
        .environmentObject(SessionStore())
}
