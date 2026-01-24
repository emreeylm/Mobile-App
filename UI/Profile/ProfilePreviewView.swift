import SwiftUI
import SwiftData

struct ProfilePreviewView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @Query private var mediaItems: [MediaItem]
    @Query private var profileMedia: [ProfileMedia]

    @State private var showSignOut = false

    var body: some View {
        ZStack {
            // Background
            AppTheme.background
                .ignoresSafeArea()

            if let profile = session.currentProfile {
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Custom Header
                        headerView
                        
                        // 2. Main Profile Image
                        mainImageView(profile: profile)
                        
                        // 3. Identity Section
                        identitySection(profile: profile)
                        
                        // 4. Info Grid
                        infoGrid(profile: profile)
                        
                        // 5. Personal Narrative
                        bioSection(profile: profile)
                        
                        // 6. Interests (Genres)
                        interestsSection(profile: profile)
                        
                        // 7. My Media (Specific Movies & Series)
                        mediaListSection(profile: profile, type: .movie, title: "FİLMLERİM")
                        mediaListSection(profile: profile, type: .series, title: "DİZİLERİM")

                        Spacer(minLength: 120) // Tab bar clearance
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
            } else {
                Text("Profil bulunamadı.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarHidden(true)
        .alert("Çıkış Yap", isPresented: $showSignOut) {
            Button("Çıkış", role: .destructive) { session.signOut() }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Hesabından çıkış yapmak istediğine emin misin?")
        }
    }

    // MARK: - Components

    private var headerView: some View {
        HStack {
            Spacer()

            Menu {
                NavigationLink("Profili Düzenle") {
                    ProfileEditView()
                }
                Button("Çıkış Yap", role: .destructive) {
                    showSignOut = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.text.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
            }
        }
        .padding(.top, 10)
    }

    private func mainImageView(profile: Profile) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoData = profile.photos.sorted(by: { $0.order < $1.order }).first?.data,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width - 48, height: UIScreen.main.bounds.width - 48)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(AppTheme.text.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 32)
                    .fill(AppTheme.text.opacity(0.05))
                    .frame(width: UIScreen.main.bounds.width - 48, height: UIScreen.main.bounds.width - 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(AppTheme.text.opacity(0.2))
                    )
            }

            // Online Indicator
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(AppTheme.main, lineWidth: 2))
                .offset(x: -4, y: 4)
        }
    }

    private func identitySection(profile: Profile) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(profile.firstName), \(profile.age)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 20))
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(AppTheme.text.opacity(0.6))
                    .font(.system(size: 16))
                
                Text(profile.city)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text.opacity(0.6))
            }

            Text("ŞİMDİ AKTİF")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .kerning(1.2)
                .padding(.top, 4)
        }
    }

    private func infoGrid(profile: Profile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            infoCard(icon: "ruler", value: profile.height, label: "BOY")
            infoCard(icon: "sun.max", value: profile.zodiac, label: "BURÇ")
            infoCard(icon: "briefcase", value: profile.jobTitle, label: "MESLEK")
            infoCard(icon: "nosign", value: profile.smokingHabit, label: "ALIŞKANLIK")
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.text)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.text.opacity(0.4))
                    .kerning(0.5)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
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
                    ForEach(list, id: \.id) { item in
                        HStack(spacing: 12) {
                            Image(systemName: type == .movie ? "film" : "tv")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.text.opacity(0.6))
                            
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.text)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(AppTheme.text.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.text.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct FlowLayout: View {
    let items: [String]
    let viewForItem: (String) -> AnyView
    @State private var totalHeight = CGFloat.zero

    init<V: View>(items: [String], @ViewBuilder viewForItem: @escaping (String) -> V) {
        self.items = items
        self.viewForItem = { AnyView(viewForItem($0)) }
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight) // ✅ Dynamically set height
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.items, id: \.self) { item in
                self.viewForItem(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == self.items.last {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == self.items.last {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

#Preview {
    ProfilePreviewView()
        .environmentObject(SessionStore())
}
