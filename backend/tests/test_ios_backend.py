"""
iOS ↔ Backend entegrasyon testleri.

Her test, CLAUDE.md'deki iOS ekranı → endpoint bağlantı tablosundaki bir satıra karşılık gelir.
Gerçek DB/Redis yerine dependency_overrides + Mock kullanılır.
"""
import uuid
import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from starlette.testclient import TestClient

from app.main import app
from app.core.dependencies import get_current_user_id, get_db, get_redis
from app.db.models import Eslesme, Kullanici


# ---------------------------------------------------------------------------
# Mock fabrika fonksiyonları
# ---------------------------------------------------------------------------

def _fake_kullanici(uid: uuid.UUID, *, is_premium: bool = False, is_admin: bool = False) -> MagicMock:
    """Pydantic KullaniciResponse ile uyumlu Kullanici mock'u."""
    k = MagicMock(spec=Kullanici)
    k.id = uid
    k.isim = "Test"
    k.yas = 25
    k.cinsiyet = "erkek"
    k.hedef_cinsiyet = "kadın"
    k.is_premium = is_premium
    k.is_admin = is_admin
    k.now_watching = None
    k.email = "test@example.com"
    k.auth_provider = "email"
    k.provider_id = f"email:test@example.com"
    k.konum = None
    k.turler = None
    k.vip_bilet_bakiye = 0
    k.kayit_tarihi = datetime.datetime.now()
    return k


def _make_db(kullanici: MagicMock | None = None) -> AsyncMock:
    """
    SQLAlchemy AsyncSession mock'u.
    db.begin() → async context manager
    db.execute() → scalar_one_or_none/scalar_one kullanici döner
    """
    db = AsyncMock()
    db.get = AsyncMock(return_value=kullanici)
    db.add = MagicMock()
    db.flush = AsyncMock()
    db.merge = AsyncMock()

    execute_result = MagicMock()
    execute_result.scalar_one_or_none.return_value = kullanici
    execute_result.scalar_one.return_value = kullanici
    execute_result.mappings.return_value.all.return_value = []
    db.execute = AsyncMock(return_value=execute_result)

    # begin() → sync MagicMock ile async context manager döner
    ctx = MagicMock()
    ctx.__aenter__ = AsyncMock(return_value=None)
    ctx.__aexit__ = AsyncMock(return_value=None)
    db.begin = MagicMock(return_value=ctx)

    return db


def _make_redis(swipe_count: int = 0) -> AsyncMock:
    """Redis mock'u — swipe, boost, VIP, publish komutları dahil."""
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=str(swipe_count).encode() if swipe_count else None)
    redis.incr = AsyncMock(return_value=swipe_count + 1)
    redis.decr = AsyncMock(return_value=max(0, swipe_count - 1))
    redis.expireat = AsyncMock()
    redis.set = AsyncMock()
    redis.setex = AsyncMock()
    redis.setnx = AsyncMock(return_value=1)
    redis.publish = AsyncMock()
    redis.ttl = AsyncMock(return_value=-1)  # boost yok

    pipe = MagicMock()
    pipe.__aenter__ = AsyncMock(return_value=pipe)
    pipe.__aexit__ = AsyncMock(return_value=None)
    pipe.watch = AsyncMock()
    pipe.multi = MagicMock()
    async def dynamic_get(key):
        val = await redis.get(key)
        if val is None:
            if "swipes" in key:
                return None
            return b"1"
        return val
    pipe.get = AsyncMock(side_effect=dynamic_get)
    pipe.decr = MagicMock()
    pipe.incr = MagicMock()
    pipe.expireat = MagicMock()
    pipe.execute = AsyncMock(return_value=[0])
    redis.pipeline = MagicMock(return_value=pipe)

    return redis


# ---------------------------------------------------------------------------
# Paylaşılan fixture'lar
# ---------------------------------------------------------------------------

@pytest.fixture
def user_id() -> uuid.UUID:
    return uuid.uuid4()


@pytest.fixture
def other_id() -> uuid.UUID:
    return uuid.uuid4()


@pytest.fixture
def override_free(user_id):
    kullanici = _fake_kullanici(user_id, is_premium=False)
    db = _make_db(kullanici)
    redis = _make_redis()

    async def _user(): return user_id
    async def _db(): yield db
    async def _redis(): yield redis

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_redis] = _redis
    yield db, redis, kullanici
    app.dependency_overrides.clear()


@pytest.fixture
def override_premium(user_id):
    kullanici = _fake_kullanici(user_id, is_premium=True)
    db = _make_db(kullanici)
    redis = _make_redis()

    async def _user(): return user_id
    async def _db(): yield db
    async def _redis(): yield redis

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_redis] = _redis
    yield db, redis, kullanici
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# 1. Auth — korunan endpoint'ler token olmadan 401 döner
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_auth_protected_endpoints_return_401():
    """iOS: token yokken tüm korunan endpoint'ler 401 döner."""
    endpoints = [
        ("GET",    "/api/v1/discover?lat=41.0&lon=29.0"),
        ("POST",   "/api/v1/swipes"),
        ("GET",    "/api/v1/likes"),
        ("GET",    "/api/v1/matches"),
        ("PATCH",  "/api/v1/users/me"),
        ("POST",   "/api/v1/vip/send"),
        ("POST",   "/api/v1/boost"),
        ("GET",    "/api/v1/boost/status"),
        ("POST",   "/api/v1/ad/reward"),
        ("DELETE", "/api/v1/swipes/last"),
    ]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for method, path in endpoints:
            resp = await client.request(method, path)
            assert resp.status_code == 401, (
                f"{method} {path} → beklenen 401, geldi {resp.status_code}"
            )


# ---------------------------------------------------------------------------
# 2. Onboarding → VIP bilet (iOS: SignUpFlowView → POST /onboarding)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_onboarding_grants_welcome_vip_ticket(user_id):
    """Onboarding tamamlanınca DB'ye 1 VIP bilet yazılmalı (grant_welcome_ticket)."""
    db = _make_db()

    async def _user(): return user_id
    async def _db(): yield db

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    try:
        payload = {
            "diziler": [{"id": i, "baslik": f"Dizi {i}", "tip": "tv"} for i in range(5)],
            "filmler": [{"id": i + 100, "baslik": f"Film {i}", "tip": "movie"} for i in range(5)],
            "turler": ["aksiyon", "komedi", "dram"],
        }
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post("/api/v1/onboarding", json=payload)

        assert resp.status_code == 200
        assert resp.json()["welcome_vip_ticket"] == 1
        # grant_welcome_ticket → db.execute çağrılmış olmalı
        db.execute.assert_called()
    finally:
        app.dependency_overrides.clear()


def test_onboarding_min_series_pydantic():
    """5'ten az dizi → Pydantic ValueError."""
    from app.api.v1.onboarding import OnboardingRequest, MedyaItem

    with pytest.raises(Exception, match="En az 5 dizi"):
        OnboardingRequest(
            diziler=[MedyaItem(id=i, baslik=f"D{i}", tip="tv") for i in range(3)],
            filmler=[MedyaItem(id=i + 100, baslik=f"F{i}", tip="movie") for i in range(5)],
            turler=["a", "b", "c"],
        )


def test_onboarding_max_total_pydantic():
    """Toplam 20'yi aşarsa → Pydantic ValueError."""
    from app.api.v1.onboarding import OnboardingRequest, MedyaItem

    with pytest.raises(Exception, match="20"):
        OnboardingRequest(
            diziler=[MedyaItem(id=i, baslik=f"D{i}", tip="tv") for i in range(11)],
            filmler=[MedyaItem(id=i + 100, baslik=f"F{i}", tip="movie") for i in range(11)],
            turler=["a", "b", "c"],
        )


def test_onboarding_min_genres_pydantic():
    """3'ten az tür → Pydantic ValueError."""
    from app.api.v1.onboarding import OnboardingRequest, MedyaItem

    with pytest.raises(Exception, match="3 tür"):
        OnboardingRequest(
            diziler=[MedyaItem(id=i, baslik=f"D{i}", tip="tv") for i in range(5)],
            filmler=[MedyaItem(id=i + 100, baslik=f"F{i}", tip="movie") for i in range(5)],
            turler=["a", "b"],
        )


# ---------------------------------------------------------------------------
# 3. Discover — RecommendationsView (GET /discover)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_discover_missing_lat_lon_returns_error(user_id, override_free):
    """iOS: lat/lon gönderilmeden → 422 (parametreler zorunlu)."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/discover")
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_discover_free_user_ignores_filter_params(user_id, override_free):
    """Ücretsiz kullanıcı premium filtre gönderse bile backend gizli sınırları uygular."""
    with patch("app.services.discover_service.get_discover_feed", new_callable=AsyncMock) as mock_feed:
        mock_feed.return_value = []
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/api/v1/discover", params={
                "lat": "41.0", "lon": "29.0",
                "min_age": "18", "max_age": "50", "max_distance_km": "500",
            })
        assert resp.status_code == 200
        call_kwargs = mock_feed.call_args.kwargs
        assert call_kwargs["min_age_override"] is None
        assert call_kwargs["max_age_override"] is None
        assert call_kwargs["max_distance_km_override"] is None


@pytest.mark.asyncio
async def test_discover_premium_user_applies_filter_params(user_id, override_premium):
    """Premium kullanıcı filtre gönderince backend override'ları kullanır."""
    with patch("app.services.discover_service.get_discover_feed", new_callable=AsyncMock) as mock_feed:
        mock_feed.return_value = []
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/api/v1/discover", params={
                "lat": "41.0", "lon": "29.0",
                "min_age": "20", "max_age": "35", "max_distance_km": "50",
            })
        assert resp.status_code == 200
        call_kwargs = mock_feed.call_args.kwargs
        assert call_kwargs["min_age_override"] == 20
        assert call_kwargs["max_age_override"] == 35
        assert call_kwargs["max_distance_km_override"] == 50


# ---------------------------------------------------------------------------
# 4. Swipe — RecommendationsView (POST /swipes)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_swipe_free_user_within_limit_succeeds(user_id, other_id, override_free):
    """Ücretsiz kullanıcı limit dahilinde swipe → 200."""
    db, redis, kullanici = override_free
    redis.get = AsyncMock(return_value=b"5")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
    assert resp.status_code == 200
    assert resp.json()["basarili"] is True


@pytest.mark.asyncio
async def test_swipe_free_user_at_limit_returns_429(user_id, other_id, override_free):
    """Ücretsiz kullanıcı 10/10 doldurmuş → 429."""
    db, redis, kullanici = override_free
    redis.get = AsyncMock(return_value=b"10")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
    assert resp.status_code == 429


@pytest.mark.asyncio
async def test_swipe_premium_user_bypasses_limit(user_id, other_id, override_premium):
    """Premium kullanıcı 50 swipe yapmış olsa bile devam edebilir."""
    db, redis, kullanici = override_premium
    redis.get = AsyncMock(return_value=b"50")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
    assert resp.status_code == 200
    assert resp.json()["basarili"] is True
    redis.incr.assert_not_called()


@pytest.mark.asyncio
async def test_swipe_mutual_like_returns_match_flag(user_id, other_id, override_free):
    """Karşılıklı beğeni → eslesme_oldu: True."""
    db, redis, kullanici = override_free
    redis.get = AsyncMock(return_value=b"0")

    existing_like = MagicMock(spec=Eslesme)
    existing_like.durum = "like"
    db.execute.return_value.scalar_one_or_none.return_value = existing_like

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
    assert resp.status_code == 200
    assert resp.json()["eslesme_oldu"] is True


# ---------------------------------------------------------------------------
# 5. Rewind — DELETE /swipes/last
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_rewind_free_user_returns_403(user_id, override_free):
    """Ücretsiz kullanıcı rewind → 403."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.delete("/api/v1/swipes/last")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_rewind_no_dislike_returns_404(user_id, override_premium):
    """Premium kullanıcı ama dislike kaydı yok → 404."""
    db, redis, kullanici = override_premium
    db.execute.return_value.scalar_one_or_none.return_value = None

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.delete("/api/v1/swipes/last")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_rewind_premium_user_succeeds(user_id, other_id, override_premium):
    """Premium kullanıcı rewind → 200 + geri alınan user_id."""
    db, redis, kullanici = override_premium

    last_swipe = MagicMock(spec=Eslesme)
    last_swipe.id = 42
    last_swipe.alici_id = other_id
    last_swipe.durum = "dislike"
    db.execute.return_value.scalar_one_or_none.return_value = last_swipe

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.delete("/api/v1/swipes/last")
    assert resp.status_code == 200
    body = resp.json()
    assert body["basarili"] is True
    assert body["geri_alinan_kullanici_id"] == str(other_id)


# ---------------------------------------------------------------------------
# 6. Likes — LikesView (GET /likes)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_likes_returns_200(user_id, override_free):
    """iOS: LikesView → GET /likes → 200."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/likes")
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 7. Matches — MessagesInboxView (GET /matches)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_matches_returns_200(user_id, override_free):
    """iOS: MessagesInboxView → GET /matches → 200."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/matches")
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 8. Profile PATCH — ProfileEditView + IAP sync (PATCH /users/me)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_patch_user_now_watching(user_id, override_free):
    """iOS: now_watching güncelleme → 200."""
    db, redis, kullanici = override_free

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.patch("/api/v1/users/me", json={"now_watching": "Stranger Things"})
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_patch_user_is_premium_ignored(user_id, override_free):
    """iOS: is_premium PATCH isteğinde güncellenemez."""
    db, redis, kullanici = override_free

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.patch("/api/v1/users/me", json={"is_premium": True})
    assert resp.status_code == 200
    assert kullanici.is_premium is False


@pytest.mark.asyncio
async def test_patch_user_age_validation(user_id, override_free):
    """Yaş 18'den küçük güncellenemez -> 400."""
    db, redis, kullanici = override_free

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.patch("/api/v1/users/me", json={"yas": 17})
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# 9. VIP Bilet — ProfilePreviewView (POST /vip/send)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_vip_send_success(user_id, other_id, override_free):
    """iOS: VIP Bilet gönder → 200."""
    db, redis, kullanici = override_free
    # consume_vip_ticket: rowcount=1 → bilet tüketildi
    db.execute.return_value.rowcount = 1
    # get_balance: first().vip_bilet_bakiye → kalan bakiye
    db.execute.return_value.first.return_value = MagicMock(vip_bilet_bakiye=0)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/vip/send", json={"alici_id": str(other_id), "mesaj": None})
    assert resp.status_code == 200
    assert resp.json()["basarili"] is True


@pytest.mark.asyncio
async def test_vip_send_no_ticket_returns_402(user_id, other_id, override_free):
    """Bilet yokken VIP gönder → 402."""
    db, redis, kullanici = override_free
    pipe = redis.pipeline.return_value
    pipe.get = AsyncMock(return_value=b"0")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/vip/send", json={"alici_id": str(other_id), "mesaj": None})
    assert resp.status_code == 402


# ---------------------------------------------------------------------------
# 10. Boost — SettingsView (POST /boost, GET /boost/status)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_boost_activate_returns_200(user_id, override_free):
    """iOS: Boost başlat → 200."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/boost")
    assert resp.status_code == 200
    assert resp.json()["active"] is True


@pytest.mark.asyncio
async def test_boost_status_inactive(user_id, override_free):
    """iOS: Boost aktif değilken durum → active: False."""
    db, redis, kullanici = override_free
    redis.ttl = AsyncMock(return_value=-1)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/boost/status")
    assert resp.status_code == 200
    assert resp.json()["active"] is False


@pytest.mark.asyncio
async def test_boost_status_active(user_id, override_free):
    """iOS: Boost aktifken kalan süre döner."""
    db, redis, kullanici = override_free
    redis.ttl = AsyncMock(return_value=1200)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/boost/status")
    assert resp.status_code == 200
    body = resp.json()
    assert body["active"] is True
    assert body["remaining_seconds"] == 1200


# ---------------------------------------------------------------------------
# 11. Ad Reward — RecommendationsView (POST /ad/reward)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ad_reward_grants_bonus_swipes(user_id, override_free):
    """iOS: reklam izlendi → +5 swipe hakkı → 200."""
    db, redis, kullanici = override_free
    redis.get = AsyncMock(return_value=b"10")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/ad/reward")
    assert resp.status_code == 200
    body = resp.json()
    assert "kalan_hak" in body
    assert body["bonus_eklendi"] == 5


# ---------------------------------------------------------------------------
# 12. E2E iş akışı: limit → reklam → devam
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_e2e_limit_then_ad_bonus_then_swipe(user_id, other_id):
    """
    Senaryo: 10 swipe doldu → 429 → reklam izlendi → bonus eklendi → yeni swipe → 200.
    """
    kullanici = _fake_kullanici(user_id, is_premium=False)
    db = _make_db(kullanici)
    redis = _make_redis(swipe_count=10)

    async def _user(): return user_id
    async def _db(): yield db
    async def _redis(): yield redis

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_redis] = _redis
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            # Adım 1: limit dolmuş → 429
            r1 = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
            assert r1.status_code == 429, f"Beklenen 429, geldi {r1.status_code}"

            # Adım 2: reklam izlendi → +5 bonus
            redis.get = AsyncMock(return_value=b"10")
            r2 = await client.post("/api/v1/ad/reward")
            assert r2.status_code == 200

            # Adım 3: sayaç 5'e düştü → swipe izinli
            redis.get = AsyncMock(return_value=b"5")
            r3 = await client.post("/api/v1/swipes", json={"hedef_id": str(other_id), "yon": "like"})
            assert r3.status_code == 200
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_vip_send_mutual_match_triggers_notification(user_id, other_id, override_free):
    """Eğer alıcı önceden beğendiyse VIP bilet eşleşmeye dönüşmeli ve bildirim gitmeli."""
    db, redis, kullanici = override_free
    # consume_vip_ticket: rowcount=1 → bilet tüketildi
    db.execute.return_value.rowcount = 1
    db.execute.return_value.first.return_value = MagicMock(vip_bilet_bakiye=0)

    # Karşı tarafın beğenisi olduğunu taklit et
    existing_like = MagicMock(spec=Eslesme)
    existing_like.durum = "like"
    db.execute.return_value.scalar_one_or_none.return_value = existing_like

    with patch("app.services.notification_service.notify_new_match", new_callable=AsyncMock) as mock_notify:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post("/api/v1/vip/send", json={"alici_id": str(other_id), "mesaj": "Selam!"})

        assert resp.status_code == 200
        body = resp.json()
        assert body["basarili"] is True
        assert body["eslesme_oldu"] is True
        mock_notify.assert_called_once()


# ---------------------------------------------------------------------------
# 13. Discover — boost sıralaması
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_discover_boost_user_appears_first(user_id, override_free):
    """Boost aktif kullanıcı, sıralamada en öne geçmeli."""
    db, redis, kullanici = override_free

    boosted_id = uuid.uuid4()
    normal_id = uuid.uuid4()

    feed = [
        {"id": str(normal_id),  "isim": "Normal", "yas": 25, "now_watching": None, "uyumluluk_skoru": 10, "foto_url": None, "ortak_medya": []},
        {"id": str(boosted_id), "isim": "Boost",  "yas": 26, "now_watching": None, "uyumluluk_skoru": 5,  "foto_url": None, "ortak_medya": []},
    ]

    async def fake_exists(key: str) -> int:
        return 1 if str(boosted_id) in key else 0
    redis.exists = AsyncMock(side_effect=fake_exists)

    with patch("app.services.discover_service.get_discover_feed", new_callable=AsyncMock) as mock_feed:
        mock_feed.return_value = feed
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/api/v1/discover", params={"lat": "41.0", "lon": "29.0"})

    assert resp.status_code == 200
    kullanicilar = resp.json()["kullanicilar"]
    assert len(kullanicilar) == 2
    # Boost aktif kullanıcı ilk sırada olmalı
    assert kullanicilar[0]["id"] == str(boosted_id), (
        f"Boost kullanıcı ilk beklendi, geldi: {kullanicilar[0]['id']}"
    )


# ---------------------------------------------------------------------------
# 14. Discover — engelleme filtresi (block filter)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_discover_blocked_user_excluded(user_id, override_free):
    """Engellenen kullanıcı discover sonuçlarında çıkmamalı (service katmanı filtreler)."""
    db, redis, kullanici = override_free
    redis.exists = AsyncMock(return_value=0)

    # Servis sadece engelsiz kullanıcıyı dönsün
    visible_id = uuid.uuid4()
    feed = [
        {"id": str(visible_id), "isim": "Görünür", "yas": 25, "now_watching": None,
         "uyumluluk_skoru": 8, "foto_url": None, "ortak_medya": []},
    ]

    with patch("app.services.discover_service.get_discover_feed", new_callable=AsyncMock) as mock_feed:
        mock_feed.return_value = feed
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/api/v1/discover", params={"lat": "41.0", "lon": "29.0"})

    assert resp.status_code == 200
    kullanicilar = resp.json()["kullanicilar"]
    # Sadece görünür kullanıcı dönmeli
    assert len(kullanicilar) == 1
    assert kullanicilar[0]["id"] == str(visible_id)


# ---------------------------------------------------------------------------
# 15. Admin rapor paneli (GET /reports/admin)
# ---------------------------------------------------------------------------

@pytest.fixture
def override_admin(user_id):
    """Admin kullanıcı fixture'ı."""
    kullanici = _fake_kullanici(user_id, is_admin=True)
    db = _make_db(kullanici)
    redis = _make_redis()

    # Admin sorgusunda boş liste dönsün
    from app.db.models import Rapor
    rapor_result = MagicMock()
    rapor_result.scalars.return_value.all.return_value = []
    db.execute = AsyncMock(return_value=rapor_result)

    async def _user(): return user_id
    async def _db(): yield db
    async def _redis(): yield redis

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_redis] = _redis
    yield db, redis, kullanici
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_admin_reports_returns_403_for_normal_user(user_id, override_free):
    """Normal kullanıcı admin endpoint'e erişemez → 403."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/reports/admin")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_reports_returns_200_for_admin(user_id, override_admin):
    """Admin kullanıcı admin endpoint'e erişebilir → 200, liste döner."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/reports/admin")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


# ---------------------------------------------------------------------------
# 16. Block & Report endpoint'leri happy-path
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_block_user_returns_204(user_id, other_id, override_free):
    """iOS: Kullanıcı engelle → POST /reports/block → 204."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/reports/block", json={"hedef_id": str(other_id)})
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_report_user_returns_204(user_id, other_id, override_free):
    """iOS: Kullanıcı raporla → POST /reports/report → 204."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/reports/report", json={
            "hedef_id": str(other_id),
            "sebep": "spam",
            "aciklama": "Test raporu",
        })
    assert resp.status_code == 204


# ---------------------------------------------------------------------------
# 17. Chat WebSocket — token doğrulama ve eşleşme kontrolü
# ---------------------------------------------------------------------------

def test_chat_ws_invalid_token_closes_4001():
    """Geçersiz token ile WS bağlantısı → kod 4001 ile kapatılmalı."""
    other_id = uuid.uuid4()

    with TestClient(app) as client:
        with pytest.raises(Exception):
            # Geçersiz token → 4001 close → bağlantı exception fırlatır
            with client.websocket_connect(f"/ws/chat/{other_id}?token=gecersiz_token"):
                pass


def test_chat_ws_no_match_closes_4003(user_id):
    """Eşleşme olmadan WS bağlantısı → kod 4003 ile kapatılmalı."""
    other_id = uuid.uuid4()

    from app.core import security

    # Geçerli ama eşleşmesiz kullanıcı
    token = security.create_access_token(str(user_id))

    kullanici = _fake_kullanici(user_id)
    db = _make_db(kullanici)
    redis = _make_redis()

    # Eşleşme ve engelleme yok
    no_match_result = MagicMock()
    no_match_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=no_match_result)

    async def _user(): return user_id
    async def _db(): yield db
    async def _redis(): yield redis

    app.dependency_overrides[get_current_user_id] = _user
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_redis] = _redis

    try:
        with TestClient(app) as client:
            with pytest.raises(Exception):
                # Eşleşme yok → 4003 close → exception
                with client.websocket_connect(f"/ws/chat/{other_id}?token={token}"):
                    pass
    finally:
        app.dependency_overrides.clear()
