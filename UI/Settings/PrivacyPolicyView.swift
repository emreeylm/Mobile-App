import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        // Intro
                        policySection(
                            icon: "hand.raised.fill",
                            title: "Gizliliğinize Değer Veriyoruz",
                            content: """
                            Bu Gizlilik Politikası, Binge uygulamasının ("Binge", "Uygulama", "biz") kişisel verilerinizi nasıl topladığını, kullandığını ve koruduğunu açıklar. Uygulamayı kullanarak bu politikayı kabul etmiş sayılırsınız.

                            Son güncelleme: Mayıs 2026
                            """
                        )

                        policySection(
                            icon: "doc.text.fill",
                            title: "1. Topladığımız Veriler",
                            content: """
                            **Hesap Bilgileri**
                            • Ad, e-posta adresi
                            • Kimlik doğrulama sağlayıcısı (Apple, Google veya e-posta)
                            • Yaş, cinsiyet, tercihler

                            **Profil İçeriği**
                            • Profil fotoğrafları
                            • Bio metni, "şu an izlediğim" içerik
                            • Seçilen dizi, film ve tür tercihleri

                            **Konum Verisi**
                            • Yakınlardaki profilleri göstermek için yaklaşık konumunuz (şehir düzeyi). Kesin GPS konumunuz sunucularımızda saklanmaz.

                            **Kullanım Verileri**
                            • Uygulama içi etkileşimler (kaydırma, eşleşme, mesajlaşma)
                            • Hata raporları ve performans verileri
                            """
                        )

                        policySection(
                            icon: "gear.circle.fill",
                            title: "2. Verileri Nasıl Kullanıyoruz",
                            content: """
                            Topladığımız verileri şu amaçlarla kullanırız:

                            • **Eşleşme Algoritması:** Ortak dizi/film zevkine sahip kullanıcıları sizinle buluşturmak için içerik tercihlerinizi analiz ederiz.
                            • **Hesap Yönetimi:** Kimliğinizi doğrulamak ve hesabınızı güvende tutmak.
                            • **Uygulama İyileştirme:** Kullanım örüntülerini analiz ederek daha iyi bir deneyim sunmak.
                            • **Güvenlik:** Sahte hesap, spam ve kötüye kullanımı tespit edip önlemek.
                            • **İletişim:** Önemli hizmet duyuruları (pazarlama değil) göndermek.

                            Verilerinizi üçüncü taraflara **satmayız**.
                            """
                        )

                        policySection(
                            icon: "network",
                            title: "3. Üçüncü Taraf Hizmetler",
                            content: """
                            Binge aşağıdaki üçüncü taraf hizmetleri kullanır:

                            **Apple Sign in with Apple**
                            Apple'ın kimlik doğrulama hizmeti. Apple'ın gizlilik politikası geçerlidir: apple.com/tr/privacy

                            **Google OAuth2**
                            Google hesabıyla giriş için kullanılır. Google'ın gizlilik politikası geçerlidir: policies.google.com/privacy

                            **The Movie Database (TMDB)**
                            Dizi ve film verilerini sağlar. İçerik tercihlerinizin isimlerini TMDB'ye iletebiliriz. TMDB'nin politikası: themoviedb.org/privacy-policy

                            **Google AdMob**
                            Ücretsiz kullanıcılara reklamlar göstermek için kullanılır. Reklam kimliğiniz reklam kişiselleştirme için paylaşılabilir. Tercihlerinizi iOS Ayarlar > Gizlilik > Reklam bölümünden düzenleyebilirsiniz.

                            **Render / Upstash**
                            Altyapı ve önbellek hizmetlerimizi sağlar. Verileriniz AB Genel Veri Koruma Tüzüğü (GDPR) uyumlu sunucularda işlenir.
                            """
                        )

                        policySection(
                            icon: "lock.fill",
                            title: "4. Veri Güvenliği",
                            content: """
                            Verilerinizi korumak için şu önlemleri alırız:

                            • Tüm sunucu iletişimi TLS/HTTPS şifrelemesi ile gerçekleşir.
                            • Şifreler bcrypt algoritmasıyla hashlenerek saklanır; düz metin olarak tutulmaz.
                            • Kimlik doğrulama token'ları yalnızca cihazınızın güvenli Keychain alanında saklanır.
                            • Sunucular düzenli güvenlik güncellemeleri alır.

                            Hiçbir internet tabanlı iletim yöntemi %100 güvenli değildir. Güvenliğinizi en üst düzeyde tutmaya çalışsak da mutlak güvenliği garanti edemeyiz.
                            """
                        )

                        policySection(
                            icon: "person.badge.key.fill",
                            title: "5. Haklarınız",
                            content: """
                            Aşağıdaki haklarınıza saygı duyarız:

                            **Erişim Hakkı**
                            Uygulama üzerinden "Profili Düzenle" bölümünden verilerinizi görüntüleyebilirsiniz.

                            **Düzeltme Hakkı**
                            Profil bilgilerinizi dilediğiniz zaman Ayarlar > Profili Düzenle üzerinden güncelleyebilirsiniz.

                            **Silme Hakkı (Hesabı Sil)**
                            Ayarlar > Hesabı Kalıcı Olarak Sil seçeneğiyle hesabınızı ve tüm ilişkili verilerinizi (eşleşmeler, mesajlar, fotoğraflar) kalıcı olarak silebilirsiniz. Bu işlem geri alınamaz.

                            **İtiraz ve Kısıtlama Hakkı**
                            Veri işlememize itiraz edebilir ya da kısıtlanmasını talep edebilirsiniz. Bunun için bizimle iletişime geçin.

                            **Taşınabilirlik**
                            Verilerinizin makine okunabilir biçimde kopyasını talep edebilirsiniz.
                            """
                        )

                        policySection(
                            icon: "calendar.badge.clock",
                            title: "6. Veri Saklama Süresi",
                            content: """
                            Hesabınız aktif olduğu sürece verileriniz saklanır. Hesabınızı sildiğinizde:

                            • Profil bilgileriniz anında silinir.
                            • Mesajlar ve eşleşmeler 30 gün içinde yedeklerden de temizlenir.
                            • Yasal yükümlülükler gerektirmedikçe herhangi bir veri tutulmaz.

                            Reklam ve analitik verileri anonim hale getirilerek 12 aya kadar saklanabilir.
                            """
                        )

                        policySection(
                            icon: "figure.2.circle.fill",
                            title: "7. Yaş Kısıtlaması",
                            content: """
                            Binge, yalnızca 17 yaş ve üzerindeki kullanıcılara yöneliktir.

                            17 yaşından küçük bireylerin uygulamamızı kullanmasına izin vermiyoruz. Bir kullanıcının 17 yaşından küçük olduğunu tespit edersek hesabı derhal kapatır ve tüm verileri sileriz.

                            Eğer 17 yaşından küçük bir kullanıcı fark ettiyseniz lütfen bize bildirin.
                            """
                        )

                        policySection(
                            icon: "bell.badge.fill",
                            title: "8. Politika Değişiklikleri",
                            content: """
                            Bu politikayı zaman zaman güncelleyebiliriz. Önemli değişiklikler olduğunda:

                            • Uygulama içi bildirim göndeririz.
                            • Güncelleme tarihini bu sayfada belirtiriz.

                            Değişikliklerden haberdar olmak için uygulamayı güncel tutmanızı öneririz.
                            """
                        )

                        policySection(
                            icon: "envelope.fill",
                            title: "9. İletişim",
                            content: """
                            Gizlilik politikamıza ilişkin soru, şikayet veya talepleriniz için:

                            📧 destek@binge.app

                            Tüm başvurular 30 iş günü içinde yanıtlanır.
                            """
                        )

                        // Footer
                        Text("© 2026 Binge. Tüm hakları saklıdır.")
                            .font(.caption)
                            .foregroundColor(AppTheme.text.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Gizlilik Politikası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                    }
                }
            }
        }
    }

    // MARK: - Section Builder

    private func policySection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
            }

            // Content with simple markdown-style bold support
            PolicyText(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.text.opacity(0.75))
                .lineSpacing(4)
        }
        .padding(18)
        .background(AppTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - PolicyText (supports **bold** inline)

private struct PolicyText: View {
    private let segments: [Segment]

    init(_ raw: String) {
        var result: [Segment] = []
        var remaining = raw
        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "**") {
                let before = String(remaining[remaining.startIndex..<boldRange.lowerBound])
                if !before.isEmpty { result.append(.plain(before)) }
                remaining = String(remaining[boldRange.upperBound...])
                if let closeRange = remaining.range(of: "**") {
                    let boldText = String(remaining[remaining.startIndex..<closeRange.lowerBound])
                    result.append(.bold(boldText))
                    remaining = String(remaining[closeRange.upperBound...])
                } else {
                    result.append(.plain("**" + remaining))
                    remaining = ""
                }
            } else {
                result.append(.plain(remaining))
                remaining = ""
            }
        }
        self.segments = result
    }

    var body: some View {
        segments.reduce(Text("")) { acc, seg in
            switch seg {
            case .plain(let t): return acc + Text(t)
            case .bold(let t):  return acc + Text(t).fontWeight(.semibold)
            }
        }
    }

    private enum Segment {
        case plain(String)
        case bold(String)
    }
}
