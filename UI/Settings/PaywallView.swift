import SwiftUI
import StoreKit

struct PaywallView: View {

    @EnvironmentObject var subscriptionStore: AppSubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String = AppSubscriptionStore.goldProductID
    @State private var animateGradient = false
    @State private var showConfirmation = false
    @State private var confirmationTier: SubscriptionTier = .plus

    private var selectedProduct: Product? {
        subscriptionStore.products.first { $0.id == selectedProductID }
    }

    private var selectedTier: SubscriptionTier {
        selectedProductID == AppSubscriptionStore.goldProductID ? .gold : .plus
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: 28) {
                    headerSection

                    if subscriptionStore.isPremium {
                        currentTierBadge
                    }

                    planCards
                    featureList
                    ctaButton
                    restoreButton
                    finePrint

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)

            // Hata banner'ı
            if let error = subscriptionStore.purchaseError {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: subscriptionStore.purchaseError)
            }

            // Kapat butonu
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.text.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(AppTheme.text.opacity(0.08)))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }
                Spacer()
            }

            if showConfirmation {
                confirmationOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await subscriptionStore.loadProductsAndUpdateStatus() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "0F172A"), Color(hex: "1a1a3e"), Color(hex: "0F172A")],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint:   animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [AppTheme.accent.opacity(0.3), .clear],
                        center: .center, startRadius: 20, endRadius: 60
                    ))
                    .frame(width: 120, height: 120)
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(
                        colors: [AppTheme.accent, Color(hex: "D4A574")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            Text("Binge Date Premium")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Text("Film zevkine göre ruh eşini bulmak\nhiç bu kadar kolay olmamıştı")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.text.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 30)
    }

    // MARK: - Current Tier Badge

    private var currentTierBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: subscriptionStore.tier.iconName)
                .foregroundStyle(subscriptionStore.tier.color)
            Text("Aktif Plan: \(subscriptionStore.tier.displayName)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(subscriptionStore.tier.color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(subscriptionStore.tier.color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 14) {
            if subscriptionStore.products.isEmpty {
                staticPlanCard(tier: .plus, price: subscriptionStore.plusFallbackPrice, isLoading: subscriptionStore.isLoadingProducts)
                staticPlanCard(tier: .gold, price: subscriptionStore.goldFallbackPrice, isLoading: subscriptionStore.isLoadingProducts)
            } else {
                ForEach(subscriptionStore.products, id: \.id) { product in
                    planCard(product: product)
                }
            }
        }
    }

    private func staticPlanCard(tier: SubscriptionTier, price: String, isLoading: Bool) -> some View {
        let isSelected = selectedProductID == (tier == .gold ? AppSubscriptionStore.goldProductID : AppSubscriptionStore.plusProductID)
        let isCurrentTier = subscriptionStore.tier == tier
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductID = tier == .gold ? AppSubscriptionStore.goldProductID : AppSubscriptionStore.plusProductID
            }
        } label: {
            VStack(spacing: 14) {
                if tier == .gold {
                    Text("EN POPÜLER")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: "0F172A"))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 20)
                }
                Image(systemName: tier.iconName).font(.system(size: 28)).foregroundStyle(tier.color)
                Text(tier.displayName.replacingOccurrences(of: "Binge Date ", with: ""))
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.text)
                VStack(spacing: 2) {
                    if isLoading {
                        ProgressView().tint(tier.color)
                    } else {
                        Text(price).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(tier.color)
                        Text("/ay").font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.text.opacity(0.4))
                    }
                }
                if isCurrentTier { Text("Aktif ✓").font(.system(size: 12, weight: .bold)).foregroundStyle(.green) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.text.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(isSelected ? tier.color : AppTheme.text.opacity(0.08), lineWidth: isSelected ? 2 : 1))
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func planCard(product: Product) -> some View {
        let tier = product.id == AppSubscriptionStore.goldProductID ? SubscriptionTier.gold : .plus
        let isSelected = selectedProductID == product.id
        let isCurrentTier = subscriptionStore.tier == tier

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductID = product.id
            }
        } label: {
            VStack(spacing: 14) {
                if tier == .gold {
                    Text("EN POPÜLER")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: "0F172A"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 20)
                }

                Image(systemName: tier.iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(tier.color)

                Text(tier.displayName.replacingOccurrences(of: "Binge Date ", with: ""))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)

                VStack(spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(tier.color)
                    Text("/ay")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.text.opacity(0.4))
                }

                if isCurrentTier {
                    Text("Aktif ✓")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.text.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? tier.color : AppTheme.text.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NELER DAHİL?")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppTheme.text.opacity(0.4))
                .padding(.bottom, 16)
                .padding(.horizontal, 4)

            featureRow(icon: "arrow.left.arrow.right", text: "Sınırsız Swipe",
                       free: "10/gün", plus: true, gold: true)
            featureRow(icon: "eye.fill", text: "Seni Beğenenleri Gör",
                       free: false, plus: true, gold: true)
            featureRow(icon: "arrow.uturn.left", text: "Geri Al (Rewind)",
                       free: false, plus: true, gold: true)
            featureRow(icon: "star.fill", text: "SuperLike",
                       free: "1/gün", plus: "5/gün", gold: true)
            featureRow(icon: "envelope.badge.fill", text: "VIP Mesajlı Beğeni",
                       free: false, plus: true, gold: true)
            featureRow(icon: "bolt.fill", text: "Öncelikli Profil (Boost)",
                       free: false, plus: false, gold: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.text.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.text.opacity(0.06), lineWidth: 1)
        )
    }

    private func featureRow(icon: String, text: String, free: Any, plus: Any, gold: Any) -> some View {
        let activeValue: Any = selectedTier == .plus ? plus : gold
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(selectedTier.color.opacity(0.8))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.text.opacity(0.8))
            Spacer()
            Group {
                if let boolValue = activeValue as? Bool {
                    Image(systemName: boolValue ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(boolValue ? .green : AppTheme.text.opacity(0.2))
                } else if let stringValue = activeValue as? String {
                    Text(stringValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selectedTier.color)
                }
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.text.opacity(0.04)).frame(height: 1)
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            if subscriptionStore.tier == selectedTier { return }
            if let product = selectedProduct {
                Task {
                    await subscriptionStore.purchase(product)
                    if subscriptionStore.tier == selectedTier {
                        confirmationTier = selectedTier
                        withAnimation { showConfirmation = true }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation { showConfirmation = false }
                        dismiss()
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                if subscriptionStore.isPurchasing {
                    ProgressView()
                        .tint(Color(hex: "0F172A"))
                } else if subscriptionStore.tier == selectedTier {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Zaten Aktif")
                } else {
                    let price = selectedProduct?.displayPrice ?? (selectedTier == .gold ? subscriptionStore.goldFallbackPrice : subscriptionStore.plusFallbackPrice)
                    Image(systemName: "lock.open.fill")
                    Text("\(selectedTier.displayName.replacingOccurrences(of: "Binge Date ", with: "")) — \(price)/ay")
                }
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "0F172A"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: (subscriptionStore.tier == selectedTier || subscriptionStore.isPurchasing)
                        ? [.gray.opacity(0.4), .gray.opacity(0.3)]
                        : [selectedTier.color, selectedTier.color.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: selectedTier.color.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(subscriptionStore.tier == selectedTier || subscriptionStore.isPurchasing)
        .padding(.top, 8)
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task { await subscriptionStore.restorePurchases() }
        } label: {
            Text("Satın Alınanları Geri Yükle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text.opacity(0.5))
        }
        .disabled(subscriptionStore.isPurchasing)
    }

    // MARK: - Fine Print

    private var finePrint: some View {
        VStack(spacing: 8) {
            Text("Abonelik iTunes hesabınızdan tahsil edilir.\nİstediğiniz zaman App Store ayarlarından iptal edebilirsiniz.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.text.opacity(0.3))
                .multilineTextAlignment(.center)

            if subscriptionStore.isPremium {
                Button {
                    subscriptionStore.openSubscriptionManagement()
                } label: {
                    Text("Aboneliği Yönet")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(confirmationTier.color)
                Text("Hoş Geldiniz!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                Text("\(confirmationTier.displayName) aktif edildi!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.6))
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color(hex: "1E293B")))
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showConfirmation)
    }
}
