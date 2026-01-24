import SwiftUI
import SwiftData
import PhotosUI

struct ProfileSetupView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore

    @State private var step: Int = 1

    // STEP 1
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

    // STEP 2
    private let allGenres: [String] = [
        "Aksiyon","Komedi","Dram","Gerilim","Bilim Kurgu","Romantik","Korku","Gizem","Suç","Fantastik","Macera","Animasyon"
    ]
    @State private var selectedGenres: Set<String> = []
    @State private var selectedMovieIds: Set<String> = []
    @State private var selectedSeriesIds: Set<String> = []

    private let minGenres = 3
    private let minMovies = 3
    private let minSeries = 3

    @Query private var mediaItems: [MediaItem]

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {

            // Progress
            HStack(spacing: 8) {
                Capsule().fill(step == 1 ? Color.blue : Color.secondary.opacity(0.25)).frame(height: 6)
                Capsule().fill(step == 2 ? Color.blue : Color.secondary.opacity(0.25)).frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if step == 1 {
                step1
            } else {
                step2
            }
        }
        .navigationTitle("Profil Oluştur")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Geri") {
                    if step == 2 {
                        withAnimation(.easeInOut) { step = 1 }
                    }
                }
                .disabled(step == 1)
            }
        }
        .onAppear {
            seedMediaIfNeeded()
        }
        .onChange(of: pickerItems) { _, newItems in
            loadSelectedPhotos(newItems)
        }
        .alert("Eksik Bilgi", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - STEP 1

    private var step1: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

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
                } label: {
                    Text("Temel Bilgiler").font(.headline)
                }

                photosSection

                Button {
                    if validateStep1() {
                        withAnimation(.easeInOut) { step = 2 }
                    }
                } label: {
                    Text("Devam Et")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(validateStep1(silent: true) ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
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

    // MARK: - STEP 2

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
                            Text("Filmler").font(.headline)
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
                            Text("Diziler").font(.headline)
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
                    finish()
                } label: {
                    Text("Bitir")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canFinish ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
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
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNames = !fn.isEmpty && !ln.isEmpty
        let hasPhotos = photos.count >= minPhotos

        if silent { return hasNames && hasPhotos }

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

    // MARK: - Actions

    private func finish() {
        guard validateStep1() else { return }
        guard canFinish else {
            fail("Lütfen en az \(minGenres) tür, \(minMovies) film, \(minSeries) dizi seç.")
            return
        }

        guard let ownerId = session.currentUserId else {
            fail("Oturum bulunamadı. Lütfen çıkış yapıp tekrar giriş yap.")
            return
        }

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

        // Photos
        for (idx, d) in photos.enumerated() {
            let ph = ProfilePhoto(data: d, order: idx)
            modelContext.insert(ph)
            profile.photos.append(ph)
        }

        modelContext.insert(profile)

        // Media links
        for id in selectedMovieIds {
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: id))
        }
        for id in selectedSeriesIds {
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: id))
        }

        try? modelContext.save()
        session.setCurrentProfile(profile)
    }

    private func toggleSelection(id: String, set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func fail(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    // MARK: - Photos Picker

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

    // MARK: - Seed Media

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
}
