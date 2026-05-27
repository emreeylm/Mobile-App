import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var boostStatus: BoostStatusResponse? = nil
    @State private var isBoostLoading = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.text)
                                    .padding(8)
                                    .background(Circle().fill(AppTheme.text.opacity(0.1)))
                            }
                            Spacer()
                            Text("Ayarlar")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.text)
                            Spacer()
                            Color.clear.frame(width: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Hesabım Section
                        settingsSection(title: "Hesabım") {
                            VStack(spacing: 1) {
                                settingsRow(icon: "person.crop.circle", title: "Profili Düzenle") {
                                    ProfileEditView()
                                }
                                settingsRow(icon: "slider.horizontal.3", title: "Tercihler") {
                                    PreferencesView()
                                }
                            }
                        }

                        // Uygulama Section
                        settingsSection(title: "Uygulama") {
                            VStack(spacing: 1) {
                                settingsRow(icon: "info.circle", title: "Hakkında") {
                                    AboutView()
                                }
                                settingsRow(icon: "shield.lefthalf.filled", title: "Gizlilik Politikası") {
                                    Text("Gizlilik Politikası").padding()
                                }
                            }
                        }

                        // Premium Section
                        settingsSection(title: "Premium") {
                            VStack(spacing: 1) {
                                premiumRow
                                boostRow
                            }
                        }

                        // Danger Zone
                        VStack(spacing: 12) {
                            // Çıkış Yap
                            Button {
                                session.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Çıkış Yap")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            // Hesabı Sil (Apple zorunluluğu)
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    if isDeletingAccount {
                                        ProgressView().tint(.red)
                                    } else {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                    }
                                    Text("Hesabı Kalıcı Olarak Sil")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .disabled(isDeletingAccount)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .alert("Hesabı Sil", isPresented: $showDeleteConfirm) {
                            Button("Sil", role: .destructive) {
                                isDeletingAccount = true
                                Task {
                                    await session.deleteAccount(modelContext: modelContext)
                                    isDeletingAccount = false
                                }
                            }
                            Button("İptal", role: .cancel) {}
                        } message: {
                            Text("Hesabın, eşleşmelerin ve tüm mesajların kalıcı olarak silinecek. Bu işlem geri alınamaz.")
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await loadBoostStatus() }
    }

    private func loadBoostStatus() async {
        boostStatus = try? await APIClient.shared.getBoostStatus()
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.text.opacity(0.4))
                .padding(.horizontal, 24)
            
            content()
                .background(AppTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
        }
    }

    private func settingsRow<V: View>(icon: String, title: String, @ViewBuilder destination: @escaping () -> V) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.text.opacity(0.2))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var boostRow: some View {
        Button {
            guard !isBoostLoading else { return }
            isBoostLoading = true
            Task {
                defer { isBoostLoading = false }
                boostStatus = try? await APIClient.shared.activateBoost()
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Boost")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.text)
                    if let status = boostStatus, status.active {
                        let mins = status.remaining_seconds / 60
                        Text("\(mins) dk kaldı")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if isBoostLoading {
                    ProgressView().tint(AppTheme.accent)
                } else if let status = boostStatus, status.active {
                    Text("Aktif")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("Aktifleştir")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .disabled(boostStatus?.active == true)
    }

    private var premiumRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(subscriptionStore.tier.color)
                    .frame(width: 24)
                
                Text("Binge Premium")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text)
                
                Spacer()
                
                if subscriptionStore.isPremium {
                    Text(subscriptionStore.tier.displayName.replacingOccurrences(of: "Binge ", with: ""))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(subscriptionStore.tier.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(subscriptionStore.tier.color.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.text.opacity(0.2))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
