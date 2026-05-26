import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @State private var selectedTab: TabItem = .match
    
    init() {
        // Hide native tab bar globally or per view
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            
            TabView(selection: $selectedTab) {
                
                // Keşfet
                NavigationStack {
                    DiscoverView()
                }
                .tag(TabItem.discover)
                
                // Beğeniler
                NavigationStack {
                    LikesView()
                }
                .tag(TabItem.likes)
                
                // Eşleşme
                NavigationStack {
                    MatchesView()
                }
                .tag(TabItem.match)
                
                // Mesajlar
                NavigationStack {
                    MessagesInboxView()
                }
                .tag(TabItem.messages)
                
                // Profil
                NavigationStack {
                    ProfilePreviewView()
                }
                .tag(TabItem.profile)
            }
            // Ensure native bar is hidden
            .toolbar(.hidden, for: .tabBar)
            
            // Custom Floating Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selectedTab) { _, _ in
            subscriptionStore.recordAppInteraction()
        }
        .fullScreenCover(isPresented: $subscriptionStore.showPeriodicPaywall) {
            PaywallView()
        }
        // Push notification deep link — yeni eşleşme
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveMatchPush)) { _ in
            selectedTab = .match
        }
        // Push notification deep link — yeni mesaj
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveMessagePush)) { _ in
            selectedTab = .messages
        }
    }
}
