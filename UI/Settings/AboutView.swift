import SwiftUI

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.text)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                VStack(spacing: 32) {
                    Spacer()

                    // App Icon Placeholder
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "popcorn.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .overlay(
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                    )

                    VStack(spacing: 12) {
                        Text("Binge")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.text)

                        Text("Versiyon 1.0.0")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.text.opacity(0.4))
                    }

                    Text("Ortak dizi ve film zevkine dayalı\nflört uygulaması.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(6)

                    Spacer()

                    VStack(spacing: 8) {
                        Text("Made with ❤️ for Movie & Series Lovers")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.text.opacity(0.3))

                        Text("© 2026 Binge Inc.")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.text.opacity(0.2))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
