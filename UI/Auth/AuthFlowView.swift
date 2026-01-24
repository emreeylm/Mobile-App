import SwiftUI

struct AuthFlowView: View {

    @State private var mode: Mode = .signIn

    enum Mode {
        case signIn
        case signUp
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                Spacer(minLength: 10)

                // Başlık
                Text(mode == .signIn ? "Giriş Yap" : "Kayıt Ol")
                    .font(.system(size: 40, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                // İçerik
                if mode == .signIn {
                    SignInView()
                } else {
                    SignUpView()
                }

                // Alt switch butonu
                Button {
                    withAnimation(.easeInOut) {
                        mode = (mode == .signIn ? .signUp : .signIn)
                    }
                } label: {
                    Text(
                        mode == .signIn
                        ? "Hesabın yok mu? Kayıt Ol"
                        : "Zaten hesabın var mı? Giriş Yap"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
