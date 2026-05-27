import SwiftUI
import SwiftData

// MARK: - AppTheme Colors & Gradients

struct AppTheme {
    
    // Palette
    static let main = Color(hex: "141417")         // Ana arka plan
    static let accent = Color(hex: "F4F4F5")       // Buton & vurgu rengi
    static let creamAccent = Color(hex: "F4F4F5")
    static let makroTeal = Color(hex: "52C4C4")
    static let secondarySlate = Color(hex: "202024") // Kart / ikincil yüzey
    static let text = Color(hex: "F4F4F5")          // Ana metin rengi

    static let primaryGradient = LinearGradient(
        colors: [main, main],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let neonGreen = Color(hex: "00ff9d")
    static let electricPurple = Color(hex: "bd00ff")

    static let buttonGradient = LinearGradient(
        colors: [accent, Color(hex: "FAFAFA")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static var background: Color {
        main
    }
    
    static var surface: Color {
        secondarySlate
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Modifiers

struct ModernSetupButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.main)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(isDisabled ? AppTheme.accent.opacity(0.3) : AppTheme.accent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

extension View {
    func setupButtonStyle(disabled: Bool = false) -> some View {
        self.buttonStyle(ModernSetupButtonStyle(isDisabled: disabled))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundColor(AppTheme.main) // Dark text on cream
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.accent) 
            .clipShape(Capsule())
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 15, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct ModernTextFieldStyle: ViewModifier {
    var icon: String?
    
    func body(content: Content) -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.accent)
            }
            content
                .foregroundStyle(AppTheme.text)
                .accentColor(AppTheme.accent)
        }
        .padding()
        .background(Color.white.opacity(0.08)) // Very subtle light glass on dark
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.thinMaterial) // SwiftUI's material adapts well to dark mode
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppTheme.electricPurple.opacity(0.2), radius: 15, x: 0, y: 5) // Purple glow for cards
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [AppTheme.electricPurple.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
}

extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func modernInput(icon: String? = nil) -> some View {
        self.modifier(ModernTextFieldStyle(icon: icon))
    }
    
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
    
    func modernFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
    }
}

