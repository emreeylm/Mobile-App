import SwiftUI
import SwiftData
import PhotosUI

struct ProfileEditView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var age: Int = 22
    @State private var city: String = ""
    @State private var jobTitle: String = ""
    @State private var bio: String = ""

    @State private var gender: Gender = .other
    @State private var lookingFor: LookingForGender = .everyone
    
    @State private var heightValue: Int = 170
    @State private var showHeight: Bool = true
    @State private var smokingHabit: String = ""
    @State private var alcoholHabit: String = ""

    // Now Watching
    @State private var selectedShowName: String = ""
    @State private var nowWatchingSeason: Int = 1
    @State private var nowWatchingEpisode: Int = 1
    @State private var nowWatchingQuery: String = ""
    @State private var nowWatchingResults: [TMDBSearchResult] = []
    @State private var isEditingNowWatching: Bool = false

    private var nowWatchingString: String {
        guard !selectedShowName.isEmpty else { return "" }
        return "\(selectedShowName) - \(nowWatchingSeason). Sezon \(nowWatchingEpisode). Bölüm"
    }

    // photos
    @State private var photos: [Data] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newlyAddedPhotos: [Data] = []   // sadece bu oturumda eklenenler, backend'e upload edilecek
    
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private let maxPhotos = 6

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Back Button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                            Text("Geri")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppTheme.text)
                        .padding(.vertical, 8)
                        .padding(.trailing, 16)
                    }
                    
                    Spacer()
                    
                    Text("Profili Düzenle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.text)
                    
                    Spacer()
                    
                    // Invisible filler to center title
                    Color.clear.frame(width: 60, height: 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 24) {
                        photosSection

                        VStack(alignment: .leading, spacing: 20) {
                            Text("KİŞİSEL BİLGİLER")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.text.opacity(0.4))
                                .kerning(1.2)
                                .padding(.horizontal, 8)

                            VStack(spacing: 16) {
                                HStack(spacing: 10) {
                                    textField("İsim", text: $firstName)
                                    textField("Soyisim", text: $lastName)
                                }

                                textField("Şehir", text: $city)
                                textField("Meslek", text: $jobTitle)
                                
                                // Boy seçici + görünürlük
                                VStack(spacing: 10) {
                                    HStack {
                                        Text("Boy: \(heightValue) cm")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(AppTheme.text)
                                        Spacer()
                                        Stepper("", value: $heightValue, in: 140...220)
                                            .labelsHidden()
                                    }
                                    .padding()
                                    .background(AppTheme.text.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))

                                    HStack {
                                        Text("Profilimde göster")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(AppTheme.text)
                                        Spacer()
                                        Toggle("", isOn: $showHeight)
                                            .labelsHidden()
                                            .tint(AppTheme.accent)
                                    }
                                    .padding()
                                    .background(AppTheme.text.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
                                }
                                textField("Sigara", text: $smokingHabit)
                                
                                textField("Alkol Kullanımı", text: $alcoholHabit)
                                nowWatchingSection

                                HStack {
                                    Text("Yaş: \(age)")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.text)
                                    Spacer()
                                    Stepper("", value: $age, in: 18...80)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(AppTheme.text.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Cinsiyet")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(AppTheme.text.opacity(0.6))
                                    Picker("Cinsiyet", selection: $gender) {
                                        ForEach(Gender.allCases, id: \.self) { g in
                                            Text(g.rawValue).tag(g)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Tercih Edilen")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(AppTheme.text.opacity(0.6))
                                    Picker("Eşleşilmek istenen", selection: $lookingFor) {
                                        ForEach(LookingForGender.allCases, id: \.self) { g in
                                            Text(g.rawValue).tag(g)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Biyografi")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(AppTheme.text.opacity(0.6))

                                    TextEditor(text: $bio)
                                        .frame(height: 120)
                                        .padding(8)
                                        .scrollContentBackground(.hidden)
                                        .background(AppTheme.text.opacity(0.05))
                                        .foregroundColor(AppTheme.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
                                }
                            }
                        }

                        saveButton
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { loadProfile() }
        .onChange(of: selectedPhotos) { _, newItems in
            loadSelectedPhotos(newItems)
        }
        .alert("Başarılı", isPresented: $showSuccess) {
            Button("Tamam", role: .cancel) { dismiss() }
        } message: {
            Text("Profilin güncellendi.")
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FOTOĞRAFLAR")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .kerning(1.2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(photos.indices, id: \.self) { idx in
                    ZStack(alignment: .topTrailing) {
                        if let ui = UIImage(data: photos[idx]) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .clipped()
                        }

                        Button {
                            photos.remove(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.text)
                                .background(AppTheme.main.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .padding(6)
                    }
                }

                if photos.count < maxPhotos {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: maxPhotos - photos.count,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.text.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.accent)
                            )
                            .background(AppTheme.text.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }

            Text("En fazla \(maxPhotos) fotoğraf ekleyebilirsin")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.text.opacity(0.4))
        }
        .padding(20)
        .background(AppTheme.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.text.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            Text("Profili Kaydet")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent)
                .foregroundColor(AppTheme.main)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if photos.count >= maxPhotos { break }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    // Optimize image: Max 1000px and 0.7 compression
                    let optimizedData = compressImage(uiImage)

                    await MainActor.run {
                        if photos.count < maxPhotos, let finalData = optimizedData {
                            photos.append(finalData)
                            newlyAddedPhotos.append(finalData)  // yeni fotoğrafları takip et
                        }
                    }
                }
            }
            await MainActor.run { selectedPhotos = [] }
        }
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1000
        let size = image.size
        
        var newSize = size
        if size.width > maxDimension || size.height > maxDimension {
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: size.height * (maxDimension / size.width))
            } else {
                newSize = CGSize(width: size.width * (maxDimension / size.height), height: maxDimension)
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Now Watching Section

    @ViewBuilder
    private var nowWatchingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Şu an izlediğim")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppTheme.text.opacity(0.6))
                Spacer()
                if !selectedShowName.isEmpty && !isEditingNowWatching {
                    Button("Değiştir") {
                        withAnimation(.spring(response: 0.3)) {
                            isEditingNowWatching = true
                            nowWatchingQuery = ""
                            nowWatchingResults = []
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                }
            }

            if !selectedShowName.isEmpty && !isEditingNowWatching {
                // Seçili dizi kartı
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedShowName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.text)
                            Text("Sezon \(nowWatchingSeason)  •  Bölüm \(nowWatchingEpisode)")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.text.opacity(0.5))
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedShowName = ""
                                nowWatchingSeason = 1
                                nowWatchingEpisode = 1
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.text.opacity(0.35))
                                .font(.system(size: 20))
                        }
                    }

                    // Sezon & Bölüm picker'ları
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("Sezon")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.text.opacity(0.5))
                            Picker("Sezon", selection: $nowWatchingSeason) {
                                ForEach(1...30, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 90)
                            .clipped()
                            .preferredColorScheme(.dark)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text("Bölüm")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.text.opacity(0.5))
                            Picker("Bölüm", selection: $nowWatchingEpisode) {
                                ForEach(1...50, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 90)
                            .clipped()
                            .preferredColorScheme(.dark)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .background(AppTheme.text.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.25), lineWidth: 1))

            } else {
                // Arama alanı
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.text.opacity(0.4))
                    TextField("Dizi ara...", text: $nowWatchingQuery)
                        .foregroundColor(AppTheme.text)
                        .tint(AppTheme.accent)
                    if !nowWatchingQuery.isEmpty {
                        Button { nowWatchingQuery = ""; nowWatchingResults = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.text.opacity(0.3))
                        }
                    }
                }
                .padding()
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
                .task(id: nowWatchingQuery) {
                    guard !nowWatchingQuery.isEmpty else { nowWatchingResults = []; return }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    let res = (try? await TMDBService.shared.search(query: nowWatchingQuery, type: .series)) ?? []
                    nowWatchingResults = Array(res.prefix(6))
                }

                if !nowWatchingResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(nowWatchingResults, id: \.id) { result in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedShowName   = result.displayName
                                    nowWatchingSeason  = 1
                                    nowWatchingEpisode = 1
                                    nowWatchingResults = []
                                    nowWatchingQuery   = ""
                                    isEditingNowWatching = false
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    if let url = result.posterURL.flatMap({ URL(string: $0) }) {
                                        AsyncImage(url: url) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            Rectangle().fill(AppTheme.text.opacity(0.1))
                                        }
                                        .frame(width: 36, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(AppTheme.text.opacity(0.1))
                                            .frame(width: 36, height: 52)
                                    }
                                    Text(result.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.text)
                                        .lineLimit(2)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(AppTheme.accent)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if result.id != nowWatchingResults.last?.id {
                                Divider()
                                    .background(AppTheme.text.opacity(0.06))
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                    .background(AppTheme.text.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if isEditingNowWatching {
                    Button("İptal") {
                        withAnimation(.spring(response: 0.3)) {
                            isEditingNowWatching = false
                            nowWatchingQuery = ""
                            nowWatchingResults = []
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.text.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding()
            .foregroundColor(AppTheme.text)
            .tint(AppTheme.accent)
            .background(AppTheme.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.text.opacity(0.1), lineWidth: 1))
    }

    private func loadProfile() {
        guard let profile = session.currentProfile else { return }
        firstName = profile.firstName
        lastName = profile.lastName
        age = profile.age
        city = profile.city
        jobTitle = profile.jobTitle
        bio = profile.bio
        gender = profile.gender
        lookingFor = profile.lookingForGender
        // "170 cm" formatından sayıyı parse et
        let parsed = profile.height.components(separatedBy: " ").first.flatMap { Int($0) } ?? 170
        heightValue = max(140, min(220, parsed))
        showHeight = profile.showHeight
        smokingHabit = profile.smokingHabit
        alcoholHabit = profile.alcoholHabit
        // "Breaking Bad - 1. Sezon 4. Bölüm" formatını parse et
        let nw = profile.nowWatching
        if !nw.isEmpty {
            let parts = nw.components(separatedBy: " - ")
            if parts.count >= 2 {
                selectedShowName = parts[0]
                let detail = parts[1] // "1. Sezon 4. Bölüm"
                let words = detail.components(separatedBy: " ")
                // ["1.", "Sezon", "4.", "Bölüm"]
                if words.count >= 4 {
                    nowWatchingSeason  = Int(words[0].replacingOccurrences(of: ".", with: "")) ?? 1
                    nowWatchingEpisode = Int(words[2].replacingOccurrences(of: ".", with: "")) ?? 1
                }
            } else {
                selectedShowName = nw
            }
        }

        photos = profile.photos
            .sorted(by: { $0.order < $1.order })
            .map { $0.data }
    }

    private func saveProfile() {
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fn.isEmpty == false else { return }

        if let profile = session.currentProfile {
            // ✅ computed name yok: first/last güncelle
            profile.firstName = fn
            profile.lastName = ln
            profile.age = age
            profile.city = city
            profile.jobTitle = jobTitle
            profile.bio = bio
            profile.gender = gender
            profile.lookingForGender = lookingFor
            profile.height = "\(heightValue) cm"
            profile.showHeight = showHeight
            profile.smokingHabit = smokingHabit
            profile.alcoholHabit = alcoholHabit
            profile.nowWatching = nowWatchingString

            // ✅ photos relation yeniden yaz
            profile.photos.removeAll()
            for (idx, d) in photos.enumerated() {
                let ph = ProfilePhoto(data: d, order: idx)
                modelContext.insert(ph)
                profile.photos.append(ph)
            }

            try? modelContext.save()
            session.setCurrentProfile(profile)

            // Backend'e gönder (fire-and-forget; auth yoksa sessizce geçilir)
            let photosToUpload = newlyAddedPhotos
            newlyAddedPhotos.removeAll()
            Task {
                let req = UpdateUserRequest(
                    isim: fn,
                    yas: age,
                    cinsiyet: gender.rawValue,
                    hedef_cinsiyet: lookingFor.rawValue,
                    now_watching: nowWatchingString.isEmpty ? nil : nowWatchingString,
                    boy: heightValue,
                    boy_gizli: !showHeight
                )
                _ = try? await APIClient.shared.updateMe(req)
                // Yeni eklenen fotoğrafları backend'e yükle
                for photoData in photosToUpload {
                    _ = try? await APIClient.shared.uploadPhoto(data: photoData, mimeType: "image/jpeg")
                }
                await session.fetchBackendUser()
            }

            showSuccess = true

        } else {
            // normalde buraya düşmez ama safe
            guard let ownerId = session.currentUserId else { return }

            let p = Profile(
                ownerUserId: ownerId,
                firstName: fn,
                lastName: ln,
                city: city,
                jobTitle: jobTitle,
                bio: bio,
                gender: gender,
                lookingForGender: lookingFor,
                height: "\(heightValue) cm",
                smokingHabit: smokingHabit,
                alcoholHabit: alcoholHabit
            )

            for (idx, d) in photos.enumerated() {
                let ph = ProfilePhoto(data: d, order: idx)
                modelContext.insert(ph)
                p.photos.append(ph)
            }

            modelContext.insert(p)
            try? modelContext.save()
            session.setCurrentProfile(p)
            
            showSuccess = true
        }
    }
}
