import SwiftUI

struct CityPickerView: View {
    @Binding var selectedCity: String
    @State private var searchText: String = ""
    @State private var showList: Bool = false

    var filtered: [String] {
        if searchText.isEmpty { return TurkishCities.all }
        let query = searchText.lowercased(with: Locale(identifier: "tr_TR"))
        return TurkishCities.all.filter {
            $0.lowercased(with: Locale(identifier: "tr_TR")).contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Seçili şehir veya arama alanı
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.accent)
                TextField("Şehir ara…", text: $searchText)
                    .foregroundStyle(AppTheme.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { _, _ in showList = true }
                    .onTapGesture { showList = true }
                if !selectedCity.isEmpty && searchText.isEmpty {
                    Text(selectedCity)
                        .foregroundStyle(AppTheme.accent)
                        .fontWeight(.semibold)
                }
                if !searchText.isEmpty {
                    Button { searchText = ""; showList = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.text.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.text.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Şehir listesi
            if showList {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered, id: \.self) { city in
                            Button {
                                selectedCity = city
                                searchText = ""
                                showList = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                HStack {
                                    Text(city)
                                        .foregroundStyle(AppTheme.text)
                                        .font(.system(size: 15))
                                    Spacer()
                                    if city == selectedCity {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.accent)
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            Divider()
                                .background(AppTheme.text.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 280)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Türkiye 81 İl

enum TurkishCities {
    static let all: [String] = [
        "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray",
        "Amasya", "Ankara", "Antalya", "Ardahan", "Artvin",
        "Aydın", "Balıkesir", "Bartın", "Batman", "Bayburt",
        "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur",
        "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli",
        "Diyarbakır", "Düzce", "Edirne", "Elazığ", "Erzincan",
        "Erzurum", "Eskişehir", "Gaziantep", "Giresun", "Gümüşhane",
        "Hakkari", "Hatay", "Iğdır", "Isparta", "İstanbul",
        "İzmir", "Kahramanmaraş", "Karabük", "Karaman", "Kars",
        "Kastamonu", "Kayseri", "Kilis", "Kırıkkale", "Kırklareli",
        "Kırşehir", "Kocaeli", "Konya", "Kütahya", "Malatya",
        "Manisa", "Mardin", "Mersin", "Muğla", "Muş",
        "Nevşehir", "Niğde", "Ordu", "Osmaniye", "Rize",
        "Sakarya", "Samsun", "Şanlıurfa", "Siirt", "Sinop",
        "Şırnak", "Sivas", "Tekirdağ", "Tokat", "Trabzon",
        "Tunceli", "Uşak", "Van", "Yalova", "Yozgat", "Zonguldak"
    ]
}
