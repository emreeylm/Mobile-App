import SwiftUI

struct PreferencesView: View {

    @AppStorage("pref.gender") private var preferredGender: String = "Herkes"
    @AppStorage("pref.minAge") private var minAge: Int = 18
    @AppStorage("pref.maxAge") private var maxAge: Int = 35
    @AppStorage("pref.distanceKm") private var distanceKm: Int = 25

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.text)
                }
                Spacer()
                Text("Tercihler")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                Spacer()
                Color.clear.frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.background) // Give header a background

            ScrollView {
                VStack(spacing: 32) {
                    
                    // Cinsiyet Secimi
                    preferenceCard(title: "Göster", icon: "person.circle.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("İlgilendiğim Cinsiyet")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.text.opacity(0.8))
                                Spacer()
                            }
                            
                            Picker("Cinsiyet", selection: $preferredGender) {
                                Text("Erkek").tag("Erkek")
                                Text("Kadın").tag("Kadın")
                                Text("Herkes").tag("Herkes")
                            }
                            .pickerStyle(.segmented)
                            .colorMultiply(AppTheme.accent) // Tint the segmented control
                        }
                    }
                    
                    // Yaş Aralığı
                    preferenceCard(title: "Yaş Aralığı", icon: "person.2.fill") {
                        VStack(spacing: 20) {
                            HStack {
                                Text("\(minAge) - \(maxAge)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.accent)
                                Spacer()
                                Text("yaş")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.text.opacity(0.4))
                            }
                            
                            VStack(spacing: 12) {
                                customSlider(title: "Minimum", value: Binding(get: { Double(minAge) }, set: { minAge = Int($0) }), range: 18...80)
                                customSlider(title: "Maksimum", value: Binding(get: { Double(maxAge) }, set: { maxAge = Int($0) }), range: 18...80)
                            }
                            .onChange(of: maxAge) { _, newValue in
                                if newValue < minAge { minAge = newValue }
                            }
                            .onChange(of: minAge) { _, newValue in
                                if newValue > maxAge { maxAge = newValue }
                            }
                        }
                    }

                    // Mesafe
                    preferenceCard(title: "Maksimum Mesafe", icon: "location.fill") {
                        VStack(spacing: 20) {
                            HStack {
                                Text("\(distanceKm)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.accent)
                                Text("km")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.accent.opacity(0.7))
                                Spacer()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(distanceKm) },
                                    set: { distanceKm = Int($0.rounded()) }
                                ),
                                in: 1...200,
                                step: 1
                            )
                            .tint(AppTheme.accent)
                        }
                    }

                    // Info
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.accent.opacity(0.5))
                        Text("Bu ayarlar şimdilik sadece bu cihazda saklanır ve eşleşme algoritmanı etkiler.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.text.opacity(0.4))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func preferenceCard<Content: View>(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(AppTheme.text.opacity(0.4))
            .padding(.horizontal, 8)
            
            VStack {
                content()
            }
            .padding(24)
            .background(AppTheme.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(LinearGradient(colors: [AppTheme.accent.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }

    private func customSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.text.opacity(0.6))
            Slider(value: value, in: range, step: 1)
                .tint(AppTheme.accent)
        }
    }
}
