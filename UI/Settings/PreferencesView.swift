import SwiftUI

struct PreferencesView: View {

    @AppStorage("pref.minAge") private var minAge: Int = 18
    @AppStorage("pref.maxAge") private var maxAge: Int = 35
    @AppStorage("pref.distanceKm") private var distanceKm: Int = 25

    var body: some View {
        Form {
            Section("Yaş Aralığı") {
                Stepper("Minimum: \(minAge)", value: $minAge, in: 18...80)
                Stepper("Maksimum: \(maxAge)", value: $maxAge, in: 18...80)
                    .onChange(of: maxAge) { _, newValue in
                        if newValue < minAge { minAge = newValue }
                    }
                    .onChange(of: minAge) { _, newValue in
                        if newValue > maxAge { maxAge = newValue }
                    }
            }

            Section("Maksimum Mesafe") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(distanceKm) km")
                        .font(.headline)
                    Slider(
                        value: Binding(
                            get: { Double(distanceKm) },
                            set: { distanceKm = Int($0.rounded()) }
                        ),
                        in: 1...200,
                        step: 1
                    )
                }
                .padding(.vertical, 6)
            }

            Section {
                Text("Bu ayarlar şimdilik cihazında saklanır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tercihler")
    }
}
