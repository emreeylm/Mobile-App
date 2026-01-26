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
    
    @State private var height: String = ""
    @State private var smokingHabit: String = ""
    @State private var alcoholHabit: String = ""
    @State private var university: String = ""

    // photos
    @State private var photos: [Data] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private let maxPhotos = 6

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
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
                            
                            HStack(spacing: 10) {
                                textField("Boy", text: $height)
                                textField("Sigara", text: $smokingHabit)
                            }
                            
                            textField("Alkol Kullanımı", text: $alcoholHabit)
                            textField("Üniversite", text: $university)

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
                .padding(24)
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
                                .scaledToFill()
                                .frame(height: 110)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            .frame(height: 110)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.accent)
                            )
                            .background(AppTheme.text.opacity(0.02))
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
            Text("Dizaynı Kaydet")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent)
                .foregroundColor(AppTheme.main)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity((firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if photos.count >= maxPhotos { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if photos.count < maxPhotos {
                            photos.append(data)
                        }
                    }
                }
            }
            await MainActor.run { selectedPhotos = [] }
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
        height = profile.height
        smokingHabit = profile.smokingHabit
        alcoholHabit = profile.alcoholHabit
        university = profile.university

        photos = profile.photos
            .sorted(by: { $0.order < $1.order })
            .map { $0.data }
    }

    private func saveProfile() {
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fn.isEmpty == false, ln.isEmpty == false else { return }

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
            profile.height = height
            profile.smokingHabit = smokingHabit
            profile.alcoholHabit = alcoholHabit
            profile.university = university

            // ✅ photos relation yeniden yaz
            profile.photos.removeAll()
            for (idx, d) in photos.enumerated() {
                let ph = ProfilePhoto(data: d, order: idx)
                modelContext.insert(ph)
                profile.photos.append(ph)
            }

            try? modelContext.save()
            session.setCurrentProfile(profile)
            
            showSuccess = true

        } else {
            // normalde buraya düşmez ama safe
            guard let ownerId = session.currentUserId else { return }

            let p = Profile(
                ownerUserId: ownerId,
                firstName: fn,
                lastName: ln,
                age: age,
                city: city,
                jobTitle: jobTitle,
                bio: bio,
                gender: gender,
                lookingForGender: lookingFor,
                height: height,
                smokingHabit: smokingHabit,
                alcoholHabit: alcoholHabit,
                university: university
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
