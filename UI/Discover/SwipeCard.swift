import SwiftUI

struct SwipeCard: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(AppTheme.text.opacity(0.05))
            
            if let urlString = item.posterURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                             .scaledToFill()
                    case .failure(_):
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.3))
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }

            // Dark overlay for readability
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                Text(item.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(item.type == .movie ? "Film" : "Dizi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.15), radius: 18, y: 10)
    }
}
