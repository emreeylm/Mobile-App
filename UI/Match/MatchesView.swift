import SwiftUI

struct MatchesView: View {

    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @State private var showFilters = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Başlık ve Filtre Butonu
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eşleşme")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.text)

                        if !subscriptionStore.isPremium {
                            Text("\(subscriptionStore.remainingSwipes) beğeni hakkı kaldı")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(subscriptionStore.remainingSwipes <= 3 ? AppTheme.accent.opacity(0.8) : AppTheme.text.opacity(0.4))
                        }
                    }

                    Spacer()

                    Button {
                        if subscriptionStore.isPremium {
                            showFilters = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.text.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Kartları “bir tık aşağı” almak için küçük boşluk
                RecommendationsView()
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showFilters) {
            PreferencesView()
        }
    }
}
