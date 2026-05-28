import SwiftUI

struct CityPickerView: View {
    @Binding var selectedCity: String
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool

    var filtered: [String] {
        if searchText.isEmpty { return TurkishCities.all }
        let q = searchText.lowercased(with: Locale(identifier: "tr_TR"))
        return TurkishCities.all.filter {
            $0.lowercased(with: Locale(identifier: "tr_TR")).contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 10) {

            // Arama alanı
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.accent.opacity(0.7))
                TextField("Şehir ara…", text: $searchText)
                    .focused($isFocused)
                    .foregroundStyle(AppTheme.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.text.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(AppTheme.text.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? AppTheme.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )

            // Şehir listesi — her zaman açık
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered, id: \.self) { city in
                        Button {
                            selectedCity = city
                            searchText   = ""
                            isFocused    = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(city)
                                    .font(.system(
                                        size: 16,
                                        weight: city == selectedCity ? .semibold : .regular
                                    ))
                                    .foregroundStyle(
                                        city == selectedCity ? AppTheme.accent : AppTheme.text
                                    )
                                Spacer()
                                if city == selectedCity {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                        .font(.system(size: 18))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(
                                city == selectedCity
                                    ? AppTheme.accent.opacity(0.08)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)

                        if city != filtered.last {
                            Divider()
                                .background(AppTheme.text.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
            .background(AppTheme.text.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
