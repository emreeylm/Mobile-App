import SwiftUI
import SwiftData
import PhotosUI

struct SignUpFlowView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    // Step control
    @State private var step: Int = 1
    private let totalSteps = 16

    // DATA
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstName: String = ""
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -20, to: .now) ?? .now
    @State private var gender: Gender = .male
    @State private var lookingFor: LookingForGender = .everyone
    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    
    @State private var selectedGenres: Set<String> = []
    @State private var selectedMovieIds: Set<String> = []
    @State private var selectedSeriesIds: Set<String> = []
    
    @State private var movieSearchQuery: String = ""
    @State private var seriesSearchQuery: String = ""
    
    @State private var movieSearchResults: [TMDBSearchResult] = []
    @State private var seriesSearchResults: [TMDBSearchResult] = []
    @State private var isSearching = false

    @State private var movieSearchTask: Task<Void, Never>?
    @State private var seriesSearchTask: Task<Void, Never>?
    
    // PHASE 2 DATA
    @State private var selectedInterests: Set<String> = []
    @State private var heightValue: Int = 170
    @State private var heightUnit: String = "cm"
    @State private var aboutMe: String = ""
    @State private var smokingHabit: String = "Söylemek istemiyorum"
    @State private var alcoholHabit: String = "Söylemek istemiyorum"
    @State private var university: String = ""

    @Query private var mediaItems: [MediaItem]
    @State private var showError = false
    @State private var errorMessage = ""

    private let minPhotos = 2
    private let maxPhotos = 6
    private let minSelection = 5 // Filmler ve Diziler için 5
    private let minGenres = 3    // Türler için 3
    private let minInterests = 5 // İlgi alanları için 5

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header & Progress
                setupHeader
                
                // Active Step
                ZStack {
                    switch step {
                    case 1: emailStep
                    case 2: passwordStep
                    case 3: nameStep
                    case 4: photoStep
                    case 5: birthdayStep
                    case 6: genderStep
                    case 7: lookingForStep
                    case 8: movieStep
                    case 9: seriesStep
                    case 10: genreStep
                    case 11: interestStep
                    case 12: heightStep
                    case 13: aboutStep
                    case 14: smokingStep
                    case 15: alcoholStep
                    case 16: universityStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
            }
        }
        .navigationBarHidden(true)
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear { 
            seedMediaIfNeeded()
            fetchInitialMedia()
        }
        .onChange(of: pickerItems) { _, newItems in loadSelectedPhotos(newItems) }
        .onChange(of: movieSearchQuery) { _, newValue in
            if newValue.isEmpty { fetchInitialMedia() }
            else { searchMedia(query: newValue, type: .movie) }
        }
        .onChange(of: seriesSearchQuery) { _, newValue in
            if newValue.isEmpty { fetchInitialMedia() }
            else { searchMedia(query: newValue, type: .series) }
        }
    }

    private var setupHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    if step > 1 { withAnimation { step -= 1 } }
                    else { dismiss() }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.text)
                }
                
                Spacer()
                
                // Atla (Skip) Button for specific steps
                if [12, 13, 14, 15, 16].contains(step) {
                    Button("Atla") {
                        withAnimation {
                            if step == totalSteps { finishSignUp() }
                            else { step += 1 }
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.text.opacity(0.6))
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.text.opacity(0.1))
                    
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - STEPS

    private var emailStep: some View {
        stepContainer(
            title: "E-postan nedir?",
            subtitle: "Hesabını oluşturmak için geçerli bir e-posta adresi gir."
        ) {
            TextField("ornek@mail.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .setupTextFieldStyle()
        } nextAction: {
            if email.contains("@") && email.contains(".") { withAnimation { step = 2 } }
            else { fail("Lütfen geçerli bir e-posta adresi gir.") }
        }
    }

    private var passwordStep: some View {
        stepContainer(
            title: "Şifre oluştur",
            subtitle: "Hesabının güvenliği için en az 6 karakterli bir şifre belirle."
        ) {
            SecureField("••••••", text: $password)
                .setupTextFieldStyle()
        } nextAction: {
            if password.count >= 6 { withAnimation { step = 3 } }
            else { fail("Şifreniz en az 6 karakter olmalıdır.") }
        }
    }

    private var nameStep: some View {
        stepContainer(
            title: "👋 Adın ne?",
            subtitle: "Uygulamada böyle gözükeceksin."
        ) {
            TextField("Adınız", text: $firstName)
                .setupTextFieldStyle()
        } nextAction: {
            if !firstName.isEmpty { withAnimation { step = 4 } }
            else { fail("Lütfen adınızı girin.") }
        }
    }

    private var photoStep: some View {
        stepContainer(
            title: "Fotoğraflarını yükle",
            subtitle: "En az \(minPhotos) fotoğraf ekleyerek başla."
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(0..<maxPhotos, id: \.self) { idx in
                    ZStack {
                        if idx < photos.count {
                            if let ui = UIImage(data: photos[idx]) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(alignment: .topTrailing) {
                                        Button { removePhoto(at: idx) } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white)
                                                .background(.black.opacity(0.6))
                                                .clipShape(Circle())
                                                .padding(6)
                                        }
                                    }
                            }
                        } else {
                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.text.opacity(0.05))
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                            }
                        }
                    }
                }
            }
        } nextAction: {
            if photos.count >= minPhotos { withAnimation { step = 5 } }
            else { fail("Lütfen en az \(minPhotos) fotoğraf yükleyin.") }
        }
    }

    private var birthdayStep: some View {
        stepContainer(
            title: "Doğum günün ne zaman?",
            subtitle: "Yaşını hesaplamak için doğum tarihini gir."
        ) {
            DatePicker("", selection: $birthday, in: ...Calendar.current.date(byAdding: .year, value: -18, to: .now)!, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .preferredColorScheme(.dark)
                .colorMultiply(.white) // Ensure white text on dark bg
        } nextAction: {
            withAnimation { step = 6 }
        }
    }

    private var genderStep: some View {
        stepContainer(
            title: "Cinsiyetin nedir?",
            subtitle: "Seni en iyi tanımlayanı seç."
        ) {
            VStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { g in
                    selectionRow(title: g.rawValue, isSelected: gender == g) {
                        gender = g
                    }
                }
            }
        } nextAction: {
            withAnimation { step = 7 }
        }
    }

    private var lookingForStep: some View {
        stepContainer(
            title: "Kiminle eşleşmek istersin?",
            subtitle: "Tercihlerini daha sonra değiştirebilirsin."
        ) {
            VStack(spacing: 12) {
                selectionRow(title: "Herkes", isSelected: lookingFor == .everyone) { lookingFor = .everyone }
                selectionRow(title: "Kadınlar", isSelected: lookingFor == .female) { lookingFor = .female }
                selectionRow(title: "Erkekler", isSelected: lookingFor == .male) { lookingFor = .male }
            }
        } nextAction: {
            withAnimation { step = 8 }
        }
    }

    private var movieStep: some View {
        let movies = mediaItems.filter { $0.type == .movie }.sorted(by: { $0.title < $1.title })
        return stepContainer(
            title: "Favori filmlerini seç",
            subtitle: "Sinema zevkini yansıtan en az \(minSelection) film seç."
        ) {
            VStack(spacing: 16) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accent.opacity(0.6))
                    TextField("Film ara...", text: $movieSearchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent.opacity(0.2), lineWidth: 1))

                if movieSearchResults.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Filmler yükleniyor...")
                            .foregroundColor(AppTheme.text.opacity(0.4))
                        Button("Tekrar Dene") { fetchInitialMedia() }
                            .foregroundColor(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(movieSearchResults) { result in
                                let isSelected = selectedMovieIds.contains("\(result.id)")
                                tmdbMediaBox(result: result, isSelected: isSelected) {
                                    toggleSelection(result: result, type: .movie)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        } nextAction: {
            if selectedMovieIds.count >= minSelection { withAnimation { step = 9 } }
            else { fail("Lütfen en az \(minSelection) film seçin.") }
        }
        .onAppear {
            if movieSearchResults.isEmpty { fetchInitialMedia() }
        }
    }

    private var seriesStep: some View {
        let series = mediaItems.filter { $0.type == .series }.sorted(by: { $0.title < $1.title })
        return stepContainer(
            title: "Favori dizilerini seç",
            subtitle: "Zevkine uygun en az \(minSelection) dizi seç."
        ) {
            VStack(spacing: 16) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accent.opacity(0.6))
                    TextField("Dizi ara...", text: $seriesSearchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent.opacity(0.2), lineWidth: 1))

                if seriesSearchResults.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Diziler yükleniyor...")
                            .foregroundColor(AppTheme.text.opacity(0.4))
                        Button("Tekrar Dene") { fetchInitialMedia() }
                            .foregroundColor(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(seriesSearchResults) { result in
                                let isSelected = selectedSeriesIds.contains("\(result.id)")
                                tmdbMediaBox(result: result, isSelected: isSelected) {
                                    toggleSelection(result: result, type: .series)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        } nextAction: {
            if selectedSeriesIds.count >= minSelection { withAnimation { step = 10 } }
            else { fail("Lütfen en az \(minSelection) dizi seçin.") }
        }
        .onAppear {
            if seriesSearchResults.isEmpty { fetchInitialMedia() }
        }
    }

    private var genreStep: some View {
        let allGenres = ["Aksiyon","Komedi","Dram","Gerilim","Bilim Kurgu","Romantik","Korku","Gizem","Suç","Fantastik","Macera","Animasyon"]
        return stepContainer(
            title: "Sevdiğin türler",
            subtitle: "İlgini çeken en az \(minSelection) tür seç."
        ) {
            FlowLayout(items: allGenres) { genre in
                let isSelected = selectedGenres.contains(genre)
                AnyView(
                    Text(genre)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(isSelected ? AppTheme.accent : AppTheme.text.opacity(0.05))
                        .foregroundColor(isSelected ? .black : AppTheme.text)
                        .clipShape(Capsule())
                        .onTapGesture {
                            if isSelected { selectedGenres.remove(genre) }
                            else { selectedGenres.insert(genre) }
                        }
                )
            }
        } nextAction: {
            if selectedGenres.count >= minGenres { withAnimation { step = 11 } }
            else { fail("Lütfen en az \(minGenres) tür seçin.") }
        }
    }

    private var interestStep: some View {
        let sections: [(String, [(String, String)])] = [
            ("Yiyecek & İçecek", [("🍷 Şarap", "🍷 Şarap"), ("🍕 Pizza", "🍕 Pizza"), ("🥩 Et", "🥩 Et"), ("☕️ Kahve", "☕️ Kahve"), ("🌿 Vegan", "🌿 Vegan")]),
            ("Ev", [("🍳 Yemek Yapma", "🍳 Yemek Yapma"), ("🎮 Oyun", "🎮 Oyun"), ("🎲 Kutu Oyunları", "🎲 Kutu Oyunları")]),
            ("Müzik", [("🎸 Gitar", "🎸 Gitar"), ("🎧 DJ'lik", "🎧 DJ'lik"), ("🎹 Piyano", "🎹 Piyano")])
        ]
        
        return stepContainer(
            title: "İlgi alanların",
            subtitle: "Seni anlatan en az \(minInterests) başlık seç."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.0).font(.headline).foregroundColor(AppTheme.text)
                            FlowLayout(items: section.1.map { $0.0 }) { item in
                                let isSelected = selectedInterests.contains(item)
                                return AnyView(
                                    Text(item)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(isSelected ? AppTheme.accent : AppTheme.text.opacity(0.05))
                                        .foregroundColor(isSelected ? .black : AppTheme.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            if isSelected { selectedInterests.remove(item) }
                                            else { selectedInterests.insert(item) }
                                        }
                                )
                            }
                        }
                    }
                }
            }
        } nextAction: {
            if selectedInterests.count >= minInterests { withAnimation { step = 12 } }
            else { fail("Lütfen en az \(minInterests) ilgi alanı seçin.") }
        }
    }

    private var heightStep: some View {
        stepContainer(
            title: "Boyun kaç?",
            subtitle: "Bunu profilinde gösterebilirsin."
        ) {
            VStack {
                Picker("", selection: $heightValue) {
                    ForEach(140...220, id: \.self) { val in
                        Text("\(val) \(heightUnit)").tag(val)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .preferredColorScheme(.dark)
                .colorMultiply(.white)
                
                HStack(spacing: 0) {
                    Button("cm") { heightUnit = "cm" }
                        .frame(width: 60, height: 36)
                        .background(heightUnit == "cm" ? Color.white.opacity(0.1) : Color.clear)
                        .foregroundColor(AppTheme.text)
                        .clipShape(Capsule())
                    Button("ft") { heightUnit = "ft" }
                        .frame(width: 60, height: 36)
                        .background(heightUnit == "ft" ? Color.white.opacity(0.1) : Color.clear)
                        .foregroundColor(AppTheme.text)
                        .clipShape(Capsule())
                }
                .background(AppTheme.text.opacity(0.05))
                .clipShape(Capsule())
            }
        } nextAction: {
            withAnimation { step = 13 }
        }
    }

    private var aboutStep: some View {
        stepContainer(
            title: "Kendinden bahset",
            subtitle: "Hakkında kısmında görünecek kısa bir yazı yaz."
        ) {
            TextEditor(text: $aboutMe)
                .frame(height: 120)
                .padding(16)
                .background(AppTheme.text.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                )
                .foregroundColor(AppTheme.text)
        } nextAction: {
            withAnimation { step = 14 }
        }
    }

    private var smokingStep: some View {
        let options = ["Söylemek istemiyorum", "Evet", "Hayır", "Sosyal İçici"]
        return stepContainer(
            title: "Sigara kullanıyor musun?",
            subtitle: "Bu bilgi profilinde görünebilir."
        ) {
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { opt in
                    selectionRow(title: opt, isSelected: smokingHabit == opt) {
                        smokingHabit = opt
                    }
                }
            }
        } nextAction: {
            withAnimation { step = 15 }
        }
    }

    private var alcoholStep: some View {
        let options = ["Söylemek istemiyorum", "Evet", "Hayır", "Sosyal İçici"]
        return stepContainer(
            title: "Alkol tüketiyor musun?",
            subtitle: "Bu bilgi profilinde görünebilir."
        ) {
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { opt in
                    selectionRow(title: opt, isSelected: alcoholHabit == opt) {
                        alcoholHabit = opt
                    }
                }
            }
        } nextAction: {
            withAnimation { step = 16 }
        }
    }

    private var universityStep: some View {
        stepContainer(
            title: "Üniversite bilgin nedir?",
            subtitle: "Eğitim bilgilerini eklemek istersen gir."
        ) {
            TextField("Üniversite adı", text: $university)
                .setupTextFieldStyle()
        } nextAction: {
            finishSignUp()
        }
    }

    // MARK: - Helpers

    private func stepContainer<Content: View>(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content, nextAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text.opacity(0.5))
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            content()
                .padding(.horizontal, 24)
            
            Spacer()
            
            Button("Devam Et") { nextAction() }
                .setupButtonStyle()
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    private func selectionRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(AppTheme.text.opacity(isSelected ? 0 : 0.1), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(AppTheme.text.opacity(isSelected ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tmdbMediaBox(result: TMDBSearchResult, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.text.opacity(0.05))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay {
                            if let urlString = result.posterURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable()
                                             .scaledToFill()
                                    case .failure(_):
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.system(size: 30))
                                            Text(result.displayName)
                                                .font(.caption2)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 4)
                                        }
                                        .foregroundColor(AppTheme.accent.opacity(0.3))
                                    case .empty:
                                        ProgressView()
                                            .tint(AppTheme.accent)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: result.mediaType == .movie ? "film" : "tv")
                                        .font(.system(size: 36, weight: .thin))
                                    Text(result.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                }
                                .foregroundColor(AppTheme.accent.opacity(0.3))
                            }
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.accent, lineWidth: 3)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.accent)
                            .background(Circle().fill(.black).padding(2))
                            .offset(x: 10, y: -10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                Text(result.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.text)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func mediaBox(item: MediaItem, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.text.opacity(0.05))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay {
                            if let urlString = item.posterURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                         .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                            } else if let img = item.coverImage {
                                Image(systemName: img)
                                    .font(.system(size: 40, weight: .thin))
                                    .foregroundColor(AppTheme.accent.opacity(0.4))
                            }
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.accent, lineWidth: 3)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.accent)
                            .background(Circle().fill(.black).padding(2))
                            .offset(x: 10, y: -10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.text)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func removePhoto(at index: Int) {
        withAnimation { if index < photos.count { photos.remove(at: index) } }
    }

    private func fail(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { withAnimation { photos.append(data) } }
                }
            }
        }
    }

    private func finishSignUp() {
        session.signUp(email: email, password: password, modelContext: modelContext)
        guard let uid = session.currentUserId else { return }
        
        let profile = Profile(
            ownerUserId: uid,
            firstName: firstName,
            lastName: "",
            bio: aboutMe,
            gender: gender,
            lookingForGender: lookingFor,
            favoriteMovieGenres: Array(selectedGenres),
            birthday: birthday,
            height: "\(heightValue) \(heightUnit)",
            smokingHabit: smokingHabit,
            alcoholHabit: alcoholHabit,
            university: university,
            interests: Array(selectedInterests)
        )
        
        for (idx, d) in photos.enumerated() {
            let ph = ProfilePhoto(data: d, order: idx)
            modelContext.insert(ph)
            profile.photos.append(ph)
        }
        
        modelContext.insert(profile)
        
        // Save selected media items to SwiftData
        for result in movieSearchResults where selectedMovieIds.contains("\(result.id)") {
            let item = MediaItem(
                title: result.displayName, 
                type: .movie, 
                tmdbId: result.id, 
                posterPath: result.poster_path,
                backdropPath: result.backdrop_path
            )
            modelContext.insert(item)
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: item.id))
        }
        for result in seriesSearchResults where selectedSeriesIds.contains("\(result.id)") {
            let item = MediaItem(
                title: result.displayName, 
                type: .series, 
                tmdbId: result.id, 
                posterPath: result.poster_path,
                backdropPath: result.backdrop_path
            )
            modelContext.insert(item)
            modelContext.insert(ProfileMedia(profileId: profile.id, mediaId: item.id))
        }
        
        try? modelContext.save()
        session.setCurrentProfile(profile)
    }

    private func seedMediaIfNeeded() {
        if !mediaItems.isEmpty { return }
        let movies = ["Inception", "The Dark Knight", "Interstellar", "The Matrix", "Pulp Fiction", "Fight Club"]
            .map { MediaItem(title: $0, type: .movie, coverImage: "film") }
        let series = ["Breaking Bad", "Stranger Things", "Dark", "Black Mirror", "The Office", "Friends"]
            .map { MediaItem(title: $0, type: .series, coverImage: "tv") }
        for m in (movies + series) { modelContext.insert(m) }
    }

    private func searchMedia(query: String, type: MediaType) {
        if type == .movie { movieSearchTask?.cancel() }
        else { seriesSearchTask?.cancel() }

        let newTask = Task {
            if query.isEmpty {
                await MainActor.run {
                    if type == .movie { movieSearchResults = [] }
                    else { seriesSearchResults = [] }
                }
                return
            }
            
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 sec
            if Task.isCancelled { return }
            
            do {
                print("TMDB: Searching \(type) -> \(query)")
                let results = try await TMDBService.shared.search(query: query, type: type)
                if Task.isCancelled { return }
                
                await MainActor.run {
                    if type == .movie { 
                        movieSearchResults = results 
                        print("TMDB: Found \(results.count) movies")
                    } else { 
                        seriesSearchResults = results 
                        print("TMDB: Found \(results.count) series")
                    }
                }
            } catch {
                print("TMDB Search Error: \(error.localizedDescription)")
            }
        }
        
        if type == .movie { movieSearchTask = newTask }
        else { seriesSearchTask = newTask }
    }

    private func fetchInitialMedia() {
        // Fetch popular to not show empty screen
        Task {
            do {
                let m = try await TMDBService.shared.fetchPopular(type: .movie)
                let s = try await TMDBService.shared.fetchPopular(type: .series)
                await MainActor.run {
                    self.movieSearchResults = m
                    self.seriesSearchResults = s
                }
            } catch {
                print("TMDB Popular Error: \(error)")
            }
        }
    }

    private func toggleSelection(result: TMDBSearchResult, type: MediaType) {
        let idString = "\(result.id)"
        if type == .movie {
            if selectedMovieIds.contains(idString) {
                selectedMovieIds.remove(idString)
            } else {
                selectedMovieIds.insert(idString)
                // Ensure MediaItem exists in SwiftData for this ID? 
                // We'll insert it during finishSignUp to avoid redundant objects
            }
        } else {
            if selectedSeriesIds.contains(idString) {
                selectedSeriesIds.remove(idString)
            } else {
                selectedSeriesIds.insert(idString)
            }
        }
    }
}

extension View {
    func setupTextFieldStyle() -> some View {
        self.padding(24)
            .background(AppTheme.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(AppTheme.text)
            .font(.system(size: 18, weight: .medium, design: .rounded))
    }
}
