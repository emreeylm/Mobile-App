import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.pink)

            Text("DateApp")
                .font(.system(size: 34, weight: .bold))

            Text("Demo dating uygulaması.\nSwiftUI & SwiftData ile geliştirildi.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }
}
