# CLAUDE.md — Binge Date (CineDate) Proje Kılavuzu

Bu dosya Claude Code için proje bağlamı (context) sağlar. Yeni bir oturum başladığında veya bir görev verildiğinde bu dosyayı önce oku; kararlarını bu kurallara göre ver.

---

## Proje Özeti

**Binge Date (CineDate)** — ortak dizi/film zevkine dayalı iOS flört uygulaması.

- **Platform:** Native iOS (Swift & SwiftUI, MVVM)
- **Backend:** Python & FastAPI (async/await)
- **DB:** PostgreSQL + PostGIS uzantısı
- **Cache:** Redis
- **Dış API'lar:** TMDB, AdMob/AppLovin, Sign in with Apple, Google OAuth2

---

## Dizin Yapısı

```
binge-date/
├── ios/                        # Xcode projesi
│   ├── BingeDate.xcodeproj
│   ├── BingeDate/
│   │   ├── App/                # @main, AppDelegate, SceneDelegate
│   │   ├── Core/
│   │   │   ├── Auth/           # AuthViewModel, KeychainManager, OAuthHandler
│   │   │   ├── Network/        # APIClient, Endpoints, Interceptors
│   │   │   └── Models/         # User, Media, Match, VIPTicket (Codable structs)
│   │   ├── Features/
│   │   │   ├── Onboarding/     # OnboardingView + VM — en az 5 dizi, 5 film, 3 tür seçimi
│   │   │   ├── Discover/       # SwipeCardView + VM — kaydırma kartları
│   │   │   ├── Likes/          # LikesView + VM — blur/kilit açma mantığı
│   │   │   ├── Chat/           # ChatView + VM — WebSocket mesajlaşma
│   │   │   ├── Profile/        # ProfileView + VM — now_watching güncelleme
│   │   │   └── Premium/        # PremiumView, VIPTicketView, BoostView
│   │   ├── Shared/
│   │   │   ├── Components/     # BlurCardView, MatchAnimationView, AdBanner
│   │   │   └── Extensions/
│   │   └── Resources/          # Assets.xcassets, Localizable.strings
│   └── BingeDateTests/
├── backend/
│   ├── app/
│   │   ├── main.py             # FastAPI app, lifespan, CORS
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── auth.py     # POST /auth/social
│   │   │       ├── users.py    # GET/PATCH /users/me
│   │   │       ├── discover.py # GET /discover  — eşleşme algoritması
│   │   │       ├── swipes.py   # POST /swipes   — Redis kota kontrolü
│   │   │       ├── likes.py    # GET /likes     — blur mantığı
│   │   │       ├── matches.py  # GET /matches
│   │   │       ├── chat.py     # WS /ws/chat/{match_id}
│   │   │       ├── vip.py      # POST /vip/send — VIP bilet işlemleri
│   │   │       └── boost.py    # POST /boost
│   │   ├── core/
│   │   │   ├── config.py       # Settings (pydantic-settings, .env)
│   │   │   ├── security.py     # JWT encode/decode, token doğrulama
│   │   │   └── dependencies.py # get_current_user, get_redis, get_db
│   │   ├── db/
│   │   │   ├── session.py      # async SQLAlchemy engine & session
│   │   │   ├── models.py       # ORM modelleri (aşağıda şema var)
│   │   │   └── migrations/     # Alembic
│   │   ├── services/
│   │   │   ├── auth_service.py     # Apple/Google token doğrulama
│   │   │   ├── discover_service.py # PostGIS + ortak medya sorgusu
│   │   │   ├── swipe_service.py    # Redis INCR + limit kontrolü
│   │   │   ├── vip_service.py      # Redis MULTI/EXEC race condition koruması
│   │   │   ├── ad_service.py       # Rewarded ad callback doğrulama
│   │   │   └── tmdb_service.py     # TMDB API wrapper
│   │   └── schemas/            # Pydantic request/response şemaları
│   ├── tests/
│   ├── alembic.ini
│   ├── pyproject.toml
│   └── .env.example
├── infra/                      # Docker, docker-compose, nginx
└── CLAUDE.md                   # Bu dosya
```

---

## Veritabanı Şeması

```sql
-- Kullanıcılar
CREATE TABLE tbl_kullanicilar (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    auth_provider   VARCHAR(50) NOT NULL,          -- 'apple' | 'google'
    provider_id     VARCHAR(255) UNIQUE NOT NULL,
    isim            VARCHAR(100) NOT NULL,
    yas             INT NOT NULL,
    cinsiyet        VARCHAR(20) NOT NULL,
    hedef_cinsiyet  VARCHAR(20) NOT NULL,
    konum           GEOMETRY(Point, 4326),          -- PostGIS
    now_watching    VARCHAR(255),
    is_premium      BOOLEAN NOT NULL DEFAULT FALSE,
    kayit_tarihi    TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_kullanicilar_konum ON tbl_kullanicilar USING GIST(konum);

-- Medya (TMDB ID birincil anahtar)
CREATE TABLE tbl_medya (
    id          INT PRIMARY KEY,                   -- Doğrudan TMDB ID
    baslik      VARCHAR(255) NOT NULL,
    tip         VARCHAR(20) NOT NULL,              -- 'movie' | 'tv'
    afis_url    VARCHAR(255)
);

-- Kullanıcı ↔ Medya (many-to-many)
CREATE TABLE tbl_kullanici_medya (
    kullanici_id  UUID REFERENCES tbl_kullanicilar(id) ON DELETE CASCADE,
    medya_id      INT  REFERENCES tbl_medya(id)        ON DELETE CASCADE,
    PRIMARY KEY (kullanici_id, medya_id)
);

-- Beğeniler / Eşleşmeler / VIP Biletler
CREATE TABLE tbl_eslesmeler (
    id          BIGSERIAL PRIMARY KEY,
    gonderen_id UUID REFERENCES tbl_kullanicilar(id) ON DELETE CASCADE,
    alici_id    UUID REFERENCES tbl_kullanicilar(id) ON DELETE CASCADE,
    durum       VARCHAR(20) NOT NULL,              -- 'like' | 'dislike' | 'vip_bilet'
    mesaj       TEXT,                             -- sadece vip_bilet için, opsiyonel
    tarih       TIMESTAMP NOT NULL DEFAULT NOW()
);
```

---

## Backend: Temel İş Kuralları

### 1. Eşleşme Algoritması (discover_service.py)

Ücretsiz kullanıcılara UI'da yaş/mesafe filtresi gösterilmez; backend **gizli sınırlar** uygular:

```sql
SELECT hedef_user.*, COUNT(ortak.medya_id) AS uyumluluk_skoru
FROM tbl_kullanicilar hedef_user
JOIN tbl_kullanici_medya ortak ON hedef_user.id = ortak.kullanici_id
WHERE hedef_user.cinsiyet = :istenen_cinsiyet
  AND hedef_user.yas BETWEEN (:user_yas - 5) AND (:user_yas + 5)   -- gizli ±5
  AND ST_DistanceSphere(hedef_user.konum, :user_konum) <= 100000    -- gizli 100 km
  AND ortak.medya_id IN (
      SELECT medya_id FROM tbl_kullanici_medya WHERE kullanici_id = :aktif_user_id
  )
GROUP BY hedef_user.id
ORDER BY uyumluluk_skoru DESC;
```

Premium kullanıcı için `AND` koşulları kaldırılır; yaş/mesafe parametre olarak alınır. Global Mod'da mesafe filtresi tamamen düşer.

### 2. Redis Kota Yönetimi (swipe_service.py)

```python
SWIPE_KEY   = "user:swipes:count:{user_id}"
DAILY_LIMIT = 10
AD_BONUS    = 5

async def check_and_increment_swipe(redis, user_id: str) -> bool:
    key = SWIPE_KEY.format(user_id=user_id)
    current = await redis.get(key)
    if current and int(current) >= DAILY_LIMIT:
        return False                       # limit doldu
    await redis.incr(key)
    await redis.expireat(key, next_midnight_ts())
    return True
```

### 3. VIP Bilet Race Condition Koruması (vip_service.py)

```python
VIP_KEY = "user:vip_tickets:{user_id}"

async def consume_vip_ticket(redis, user_id: str) -> bool:
    key = VIP_KEY.format(user_id=user_id)
    async with redis.pipeline(transaction=True) as pipe:
        while True:
            try:
                await pipe.watch(key)
                balance = int(await pipe.get(key) or 0)
                if balance <= 0:
                    return False
                pipe.multi()
                pipe.decr(key)
                await pipe.execute()
                return True
            except WatchError:
                continue
```

### 4. OAuth2 → JWT Akışı (/api/v1/auth/social)

1. iOS'tan gelen `id_token` (Apple/Google) alınır.
2. Provider'ın public key'i ile imza doğrulanır.
3. `provider_id` ile DB'de kullanıcı aranır; yoksa yeni kayıt oluşturulur ve onboarding flag'i döner.
4. `access_token` (15 dk) + `refresh_token` (30 gün) JWT çifti döner.
5. iOS bu tokenları **Keychain**'de saklar; her API isteğinde `Authorization: Bearer <token>` kullanır.

### 5. Onboarding Validasyonu

```python
# Minimum zorunlu
assert len(selected_series) >= 5
assert len(selected_movies) >= 5
assert len(selected_genres) >= 3

# Maksimum limit
assert len(selected_series) + len(selected_movies) <= 20
```

---

## iOS: Temel Kurallar

- **Mimari:** Her Feature klasörü kendi `View` + `ViewModel` + `Model` üçlüsünü içerir. ViewModel `@MainActor` ile işaretlenir.
- **Ağ katmanı:** `APIClient` async/await + `URLSession`; her istek `AuthInterceptor` üzerinden geçer, 401 alınırsa refresh token endpoint'i tetiklenir.
- **Keychain:** Token saklama için `Security.framework` native API kullanılır; `UserDefaults` kesinlikle kullanılmaz.
- **Kaydırma animasyonu:** `DragGesture` + `withAnimation(.spring())` kombinasyonu kullanılır; kartlar `.offset` ile sahneden çıkar.
- **Blur efekti:** Beğeni gelen profil kartları `.blur(radius: 12)` + `overlay` ile maskelenir; reklam izlenince `withAnimation` ile kaldırılır.
- **Reklam:** `GADRewardedAd` (AdMob) veya AppLovin'in `MARewardedAd`'i — yalnızca `rewardedAdDidEarnReward` callback sonrası backend'e grant isteği atılır.

---

## Ortam Değişkenleri (.env)

```env
# PostgreSQL
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/bingedate

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET=<güçlü-secret>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# TMDB
TMDB_API_KEY=<tmdb-key>
TMDB_BASE_URL=https://api.themoviedb.org/3

# Google OAuth
GOOGLE_CLIENT_ID=<google-client-id>

# Apple
APPLE_TEAM_ID=<team-id>
APPLE_CLIENT_ID=<bundle-id>
```

---

## Geliştirme Kuralları

### Genel
- Yeni bir özellik eklerken önce ilgili servisi (`services/`) yaz, sonra router'ı (`api/v1/`) ekle.
- Her public fonksiyon için kısa docstring zorunludur.
- `TODO` bırakmak yerine GitHub Issue numarasını (`# TODO #42`) yaz.

### Backend
- FastAPI endpoint'leri `async def` olmalı; `time.sleep` gibi bloke eden çağrı yasaktır.
- DB işlemleri için her zaman `async with db.begin()` context manager kullanılır.
- Pydantic şemaları `schemas/` altında, ORM modelleri `db/models.py`'de tutulur; karıştırılmaz.
- Redis'e doğrudan erişim yalnızca `services/` katmanından yapılır.

### iOS
- SwiftUI preview'ları her View için yazılır.
- `print()` debug için kullanılmaz; `Logger` (os.log) kullanılır.
- API base URL environment variable'dan okunur; hardcode edilmez.

### Test
- Backend: `pytest-asyncio` + `httpx.AsyncClient` ile her endpoint için en az 1 happy-path testi.
- iOS: Her ViewModel için `XCTest` unit testi; ağ katmanı `MockAPIClient` ile stublanır.

---

## iOS–Backend Entegrasyon Durumu (Güncel)

Aşağıdaki tabloda iOS ekranlarının backend endpoint'leriyle bağlantı durumu gösterilmektedir.

| Ekran | Endpoint | Durum |
|---|---|---|
| RecommendationsView (swipe kartları) | `POST /api/v1/swipes` | ✅ Bağlı (fire-and-forget) |
| RecommendationsView (kart listesi) | `GET /api/v1/discover` | ✅ Bağlı (Profile stub oluşturur) |
| LikesView | `GET /api/v1/likes` | ✅ Bağlı |
| MessagesInboxView | `GET /api/v1/matches` | ✅ Bağlı |
| ProfileEditView | `PATCH /api/v1/users/me` | ✅ Bağlı (kayıt sonrası) |
| ProfilePreviewView → VIP butonu | `POST /api/v1/vip/send` | ✅ Bağlı |
| SettingsView → Boost satırı | `POST /api/v1/boost`, `GET /api/v1/boost/status` | ✅ Bağlı |
| RecommendationsView → Reklam butonu | `POST /api/v1/ad/reward` | ✅ Bağlı |
| DiscoverView | TMDB (medya keşfi) | ✅ Değişmedi — backend discover /discover ≠ bu sekme |
| LocationManager | `PATCH /api/v1/users/me` (konum alanı) | ✅ İlk konum alınca otomatik sync |

---

## Sık Referans Verilen Kurallar (Hızlı Özet)

| Kural | Değer |
|---|---|
| Günlük ücretsiz kaydırma | 10 |
| Reklam bonusu | +5 |
| Onboarding min dizi | 5 |
| Onboarding min film | 5 |
| Onboarding min tür | 3 |
| Onboarding max toplam yapım | 20 |
| Gizli yaş aralığı (ücretsiz) | ±5 |
| Gizli mesafe sınırı (ücretsiz) | 100 km |
| Hoş geldin VIP bilet | 1 adet |
| Boost süresi | 30 dakika |
| Access token ömrü | 15 dakika |
| Refresh token ömrü | 30 gün |
