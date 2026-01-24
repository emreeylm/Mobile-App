import SwiftUI
import SwiftData
import PhotosUI

struct SignUpFlowView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    // Step control
    @State private var step: Int = 1

    // Step 1
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var age: Int = 22
    @State private var city: String = ""
    @State private var bio: String = ""
    @State private var jobTitle: String = ""
    @State private var gender: Gender = .other
    @State private var lookingFor: LookingForGender = .everyone

    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    private let minPhotos = 2
    private let maxPhotos = 6

    // Step 2 (min requirements)
    private let allGenres: [String] = [
        "Aksiyon","Komedi","Dram","Gerilim","Bilim Kurgu","Romantik","Korku","Gizem","Suç","Fantastik","Macera","Animasyon"
    ]
    @State private var selectedGenres: Set<String> = []

    @Query private var mediaItems: [MediaItem]
    @State private var selectedMovieIds: Set<String> = []
    @State private var selectedSeriesIds: Set<String> = []

    private let minGenres = 3
    private let minMovies = 3
    private let minSeries = 3

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top progress
                HStack(spacing: 8) {
                    Capsule().fill(step == 1 ? AppTheme.accent : AppTheme.text.opacity(0.2)).frame(height: 6)
                    Capsule().fill(step == 2 ? AppTheme.accent : AppTheme.text.opacity(0.2)).frame(height: 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if step == 1 {
                    step1
                } else {
                    step2
                }
            }
        }
        .navigationTitle("Kayıt Ol")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Geri") {
                    if step == 1 { dismiss() }
                    else { withAnimation { step = 1 } }
                }
            }
        }
        .onAppear { seedMediaIfNeeded() }
        .onChange(of: pickerItems) { _, newItems in loadSelectedPhotos(newItems) }
        .alert("Eksik Bilgi", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    // MARK: - STEP 1 UI

    private var step1: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox {
                    VStack(spacing: 12) {
                        TextField("E-posta", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(AppTheme.text.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundColor(AppTheme.text)

                        SecureField("Şifre", text: $password)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(AppTheme.text.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundColor(AppTheme.text)
                    }
                } label: { Text("Hesap Bilgileri").font(.headline).foregroundColor(AppTheme.text) }

                GroupBox {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            TextField("İsim", text: $firstName)
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            TextField("Soyisim", text: $lastName)
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Stepper("Yaş: \(age)", value: $age, in: 18...80)

                        TextField("Şehir", text: $city)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        TextField("Meslek (opsiyonel)", text: $jobTitle)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Biyografi")
                                .font(.subheadline.weight(.semibold))
                            TextEditor(text: $bio)
                                .frame(height: 110)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Picker("Cinsiyet", selection: $gender) {
                            ForEach(Gender.allCases, id: \.self) { g in
                                Text(g.rawValue).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Eşleşilmek istenen", selection: $lookingFor) {
                            ForEach(LookingForGender.allCases, id: \.self) { g in
                                Text(g.rawValue).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } label: { Text("Profil Bilgileri").font(.headline) }

                photosSection

                Button {
                    if validateStep1() {
                        withAnimation { step = 2 }
                    }
                } label: {
                    Text("Devam Et")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(validateStep1(silent: true) ? AppTheme.accent : AppTheme.text.opacity(0.3))
                        .foregroundStyle(AppTheme.main)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!validateStep1(silent: true))
                .padding(.top, 6)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
    }

    private var photosSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("En az \(minPhotos), en fazla \(maxPhotos) fotoğraf")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(photos.indices, id: \.self) { idx in
                        ZStack(alignment: .topTrailing) {
                            if let ui = UIImage(data: photos[idx]) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 120)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            Button {
                                photos.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(6)
                        }
                    }

                    if photos.count < maxPhotos {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxPhotos - photos.count,
                            matching: .images
                        ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    .frame(height: 120)
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } label: {
            Text("Fotoğraflar").font(.headline)
        }
    }

    // MARK: - STEP 2 UI

    private var step2: some View {
        let movies = mediaItems.filter { $0.type == .movie }.sorted { $0.title < $1.title }
        let series = mediaItems.filter { $0.type == .series }.sorted { $0.title < $1.title }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox {
                    GenreChips(items: allGenres, selected: $selectedGenres)
                    Text("En az \(minGenres) tür seç")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } label: {
                    Text("Film/Dizi Türleri").font(.headline)
                }

                GroupBox {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Filmler")
                                .font(.headline)
                            Spacer()
                            Text("\(selectedMovieIds.count)/\(minMovies)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedMovieIds.count >= minMovies ? .green : .secondary)
                        }

                        ForEach(movies, id: \.id) { item in
                            SelectRow(
                                title: item.title,
                                isSelected: selectedMovieIds.contains(item.id),
                                onTap: { toggleSelection(id: item.id, set: &selectedMovieIds) }
                            )
                        }
                    }
                }

                GroupBox {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Diziler")
                                .font(.headline)
                            Spacer()
                            Text("\(selectedSeriesIds.count)/\(minSeries)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedSeriesIds.count >= minSeries ? .green : .secondary)
                        }

                        ForEach(series, id: \.id) { item in
                            SelectRow(
                                title: item.title,
                                isSelected: selectedSeriesIds.contains(item.id),
                                onTap: { toggleSelection(id: item.id, set: &selectedSeriesIds) }
                            )
                        }
                    }
                }

                Button {
                    finishSignUp()
                } label: {
                    Text("Hesabı Oluştur")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canFinish ? AppTheme.accent : AppTheme.text.opacity(0.3))
                        .foregroundStyle(AppTheme.main)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canFinish)
                .padding(.top, 6)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
    }

    // MARK: - Validation

    private func validateStep1(silent: Bool = false) -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let has = !e.isEmpty && !p.isEmpty && !fn.isEmpty && !ln.isEmpty
        let hasPhotos = photos.count >= minPhotos

        if silent { return has && hasPhotos }

        if e.isEmpty { fail("E-posta gir."); return false }
        if p.isEmpty { fail("Şifre gir."); return false }
        if fn.isEmpty { fail("İsim gir."); return false }
        if ln.isEmpty { fail("Soyisim gir."); return false }
        if photos.count < minPhotos { fail("En az \(minPhotos) fotoğraf ekle."); return false }
        return true
    }

    private var canFinish: Bool {
        selectedGenres.count >= minGenres &&
        selectedMovieIds.count >= minMovies &&
        selectedSeriesIds.count >= minSeries
    }

    // MARK: - Finish

    private func finishSignUp() {
        guard validateStep1() else { return }
        guard canFinish else {
            fail("Lütfen en az \(minGenres) tür, \(minMovies) film, \(minSeries) dizi seç.")
            return
        }

        // 1) Auth kayıt (demo)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        session.signUp(email: e, password: p, modelContext: modelContext)

        // 2) owner id garanti
        guard let ownerId = session.currentUserId else {
            fail("Oturum oluşmadı. Tekrar dene.")
            return
        }

        // 3) Profile create
        let profile = Profile(
            ownerUserId: ownerId,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            city: city,
            jobTitle: jobTitle,
            bio: bio,
            gender: gender,
            lookingForGender: lookingFor,
            favoriteMovieGenres: Array(selectedGenres)
        )

        // photos relation
        for (idx, d) in photos.enumerated() {
            let ph = ProfilePhoto(data: d, order: idx)
            modelContext.insert(ph)
            profile.photos.append(ph)
        }

        modelContext.insert(profile)

        // media links
        for id in selectedMovieIds {
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: id))
        }
        for id in selectedSeriesIds {
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: id))
        }

        try? modelContext.save()
        session.setCurrentProfile(profile)
    }

    // MARK: - Helpers

    private func toggleSelection(id: String, set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func fail(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    private func seedMediaIfNeeded() {
        if mediaItems.isEmpty == false { return }

        let movies = [
            "Interstellar","Inception","The Dark Knight","Fight Club","The Matrix",
            "Whiplash","Parasite","Joker","Forrest Gump","Shutter Island"
        ].map { MediaItem(title: $0, type: .movie) }

        let series = [
            "Breaking Bad","Dark","Black Mirror","Sherlock","The Office",
            "Stranger Things","Narcos","Mr. Robot","The Boys","Game of Thrones"
        ].map { MediaItem(title: $0, type: .series) }

        for m in (movies + series) { modelContext.insert(m) }
        try? modelContext.save()
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if photos.count >= maxPhotos { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if photos.count < maxPhotos { photos.append(data) }
                    }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
    }
}
