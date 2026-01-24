import SwiftUI

struct SwipeCard: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 10) {
                Spacer()

                Text(item.title)
                    .font(.title2.weight(.bold))

                Text(item.type == .movie ? "Film" : "Dizi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)

            // ✅ Poster yerine ikon (posterSymbol yoktu)
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: item.type == .movie ? "film" : "tv")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(18)
                }
                Spacer()
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
    }
}
