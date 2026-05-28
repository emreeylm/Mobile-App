"""Auth endpoint happy-path testleri."""
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from app.main import app


@pytest.fixture
def mock_google_verify():
    with patch("app.services.auth_service.verify_google_token", new_callable=AsyncMock) as m:
        m.return_value = {"sub": "google_123", "email": "test@example.com", "name": "Test User"}
        yield m


@pytest.fixture
def mock_db_user(tmp_path):
    """SQLAlchemy oturumunu mock'lar — gerçek DB gerekmez."""
    import uuid
    from unittest.mock import MagicMock, AsyncMock, patch
    from app.db.models import Kullanici

    fake_user = MagicMock(spec=Kullanici)
    fake_user.id = uuid.uuid4()

    with patch("app.api.v1.auth.get_db") as mock_get_db, \
         patch("app.api.v1.auth.get_redis") as mock_get_redis:

        mock_session = AsyncMock()
        mock_session.__aenter__ = AsyncMock(return_value=mock_session)
        mock_session.__aexit__ = AsyncMock(return_value=None)
        mock_session.begin = MagicMock(return_value=mock_session)
        mock_session.scalar_one_or_none = AsyncMock(return_value=None)
        mock_session.flush = AsyncMock()
        mock_session.add = MagicMock()
        mock_session.flush = AsyncMock(side_effect=lambda: setattr(fake_user, "id", fake_user.id))

        mock_get_db.return_value.__anext__ = AsyncMock(return_value=mock_session)

        mock_redis = AsyncMock()
        mock_get_redis.return_value.__anext__ = AsyncMock(return_value=mock_redis)

        yield fake_user


@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_social_login_invalid_provider():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/auth/social", json={"provider": "twitter", "id_token": "xxx"})
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_swipe_limit_schema():
    """SwipeRequest schema validasyonu."""
    from app.schemas.swipe import SwipeRequest
    import uuid
    req = SwipeRequest(hedef_id=uuid.uuid4(), yon="like")
    assert req.yon == "like"


@pytest.mark.asyncio
async def test_onboarding_validation():
    """Onboarding minimum kural kontrolleri."""
    from app.api.v1.onboarding import OnboardingRequest, MedyaItem
    import pytest

    def make_item(i):
        return MedyaItem(id=i, baslik=f"Item {i}", tip="tv")

    with pytest.raises(Exception):
        OnboardingRequest(diziler=[make_item(i) for i in range(3)], filmler=[make_item(i) for i in range(5, 10)], turler=["a", "b", "c"])

    valid = OnboardingRequest(
        diziler=[make_item(i) for i in range(5)],
        filmler=[make_item(i) for i in range(5, 10)],
        turler=["aksiyon", "komedi", "dram"],
    )
    assert len(valid.diziler) == 5


@pytest.mark.asyncio
async def test_swipe_requires_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/swipes", json={"hedef_id": "00000000-0000-0000-0000-000000000001", "yon": "like"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_matches_requires_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/matches")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_discover_requires_query_params():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/discover")
    assert resp.status_code != 200


@pytest.mark.asyncio
async def test_likes_requires_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/likes")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_boost_status_requires_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/boost/status")
    assert resp.status_code == 401


# MARK: - Telefon OTP testleri (servis katmanı)

@pytest.mark.asyncio
async def test_generate_otp_format():
    """generate_otp 6 haneli sayısal string üretmeli."""
    from app.services.sms_service import generate_otp
    for _ in range(20):
        otp = generate_otp()
        assert len(otp) == 6
        assert otp.isdigit()
        assert 100000 <= int(otp) <= 999999


@pytest.mark.asyncio
async def test_phone_otp_request_schema():
    """PhoneOTPRequest schema doğrulaması."""
    from app.schemas.auth import PhoneOTPRequest
    req = PhoneOTPRequest(telefon="+905551234567")
    assert req.telefon == "+905551234567"


@pytest.mark.asyncio
async def test_phone_verify_schema():
    """PhoneVerifyRequest schema doğrulaması."""
    from app.schemas.auth import PhoneVerifyRequest
    req = PhoneVerifyRequest(telefon="+905551234567", otp_code="123456")
    assert req.otp_code == "123456"


@pytest.mark.asyncio
async def test_phone_otp_endpoint_requires_body():
    """Body olmadan 422 dönmeli."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/auth/phone/request-otp", json={})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_phone_verify_endpoint_requires_body():
    """Eksik body alanıyla 422 dönmeli."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/auth/phone/verify-otp", json={"telefon": "+905551234567"})
    assert resp.status_code == 422
