import SwiftUI

struct MatchesView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                // Başlık (Beğeniler gibi)
                Text("Eşleşme")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                // Kartları “bir tık aşağı” almak için küçük boşluk
                RecommendationsView()
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }
        }
    }
}
