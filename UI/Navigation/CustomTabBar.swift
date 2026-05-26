import SwiftUI

enum TabItem: String, CaseIterable {
    case discover = "sparkles"
    case likes = "hand.thumbsup.fill"
    case match = "heart.fill"
    case messages = "message.fill"
    case profile = "person.crop.circle.fill"
    
    var title: String {
        switch self {
        case .discover: return "Keşfet"
        case .match: return "Eşleşme"
        case .likes: return "Beğeniler"
        case .messages: return "Mesajlar"
        case .profile: return "Profil"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        HStack {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 24, weight: selectedTab == tab ? .bold : .regular))
                            .scaleEffect(selectedTab == tab ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)

                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 4, height: 4)
                            .opacity(selectedTab == tab ? 1 : 0)
                            .scaleEffect(selectedTab == tab ? 1 : 0.1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab)
                    }
                    .foregroundColor(selectedTab == tab ? AppTheme.accent : AppTheme.text.opacity(0.3))
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 34) // Safe area
        .background(
            ZStack {
                AppTheme.main
                    .opacity(0.95)
                
                // Subtle Top Border
                VStack {
                    Divider()
                        .background(AppTheme.text.opacity(0.1))
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: -5)
        )
        .padding(.horizontal)
    }
    
}
