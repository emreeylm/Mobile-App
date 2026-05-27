import SwiftUI

/// A reusable premium feature gate overlay.
/// Shows a lock icon, feature description, and a button to open PaywallView.
struct PremiumFeatureGate: View {

    let feature: String
    let icon: String
    let description: String
    
    @State private var showPaywall = false
    @State private var animatePulse = false

    init(feature: String, icon: String = "lock.fill", description: String = "") {
        self.feature = feature
        self.icon = icon
        self.description = description.isEmpty ? "\(feature) için Premium'a geç" : description
    }

    var body: some View {
        VStack(spacing: 20) {
            // Lock Icon with pulse
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 90, height: 90)
                    .scaleEffect(animatePulse ? 1.15 : 1.0)
                    .opacity(animatePulse ? 0.3 : 0.8)
                
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animatePulse = true
                }
            }
            
            VStack(spacing: 8) {
                Text(feature)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Premium'a Geç")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "141417"))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.secondarySlate.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// Inline banner for premium upsell (smaller, used within lists)
struct PremiumBanner: View {
    
    @State private var showPaywall = false
    
    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Binge Premium")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                    
                    Text("Tüm özellikleri aç")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.text.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.accent.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.08), AppTheme.accent.opacity(0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
