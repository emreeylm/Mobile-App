"""AdMob SSV ve reward endpoint testleri."""
import pytest
from unittest.mock import AsyncMock, patch
from app.services.ad_service import build_admob_verify_string, verify_admob_ssv


def test_build_admob_verify_string_excludes_signature():
    params = {
        "ad_unit_id": "ca-app-pub-xxx",
        "reward_amount": "1",
        "timestamp": "1700000000",
        "signature": "abc123",
        "key_id": "1",
    }
    result = build_admob_verify_string(params)
    assert "signature" not in result
    assert "key_id" not in result
    assert "ad_unit_id" in result


def test_build_admob_verify_string_sorted():
    """Parametreler alfabetik sırada birleştirilmeli."""
    params = {"z_param": "1", "a_param": "2", "m_param": "3", "signature": "x", "key_id": "1"}
    result = build_admob_verify_string(params)
    assert result.index("a_param") < result.index("m_param") < result.index("z_param")


@pytest.mark.asyncio
async def test_verify_admob_ssv_missing_key_returns_false():
    """Bilinmeyen key_id → False döner (key fetch mock'lu)."""
    with patch("app.services.ad_service._fetch_admob_keys", new_callable=AsyncMock):
        with patch("app.services.ad_service._key_cache", {}):
            result = await verify_admob_ssv({"key_id": "99999", "signature": "bad"})
    assert result is False


@pytest.mark.asyncio
async def test_verify_admob_ssv_invalid_signature_returns_false():
    """Geçerli key_id ama yanlış imza → False döner."""
    from cryptography.hazmat.primitives.asymmetric import ec

    private_key = ec.generate_private_key(ec.SECP256K1())
    public_key = private_key.public_key()

    with patch("app.services.ad_service._get_public_key", new_callable=AsyncMock) as mock_key:
        mock_key.return_value = public_key
        result = await verify_admob_ssv({
            "key_id": "12345",
            "signature": "aW52YWxpZA==",  # "invalid" base64
            "ad_unit_id": "test",
        })
    assert result is False


@pytest.mark.asyncio
async def test_verify_admob_ssv_valid_signature():
    """Doğru key ile imzalanmış istek → True döner."""
    import base64
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import hashes

    private_key = ec.generate_private_key(ec.SECP256K1())
    public_key = private_key.public_key()

    params = {"ad_unit_id": "ca-app-pub-test", "reward_amount": "1", "timestamp": "1700000000",
              "key_id": "12345", "signature": "placeholder"}
    verify_str = build_admob_verify_string(params)
    raw_sig = private_key.sign(verify_str.encode(), ec.ECDSA(hashes.SHA256()))
    sig_b64 = base64.urlsafe_b64encode(raw_sig).decode().rstrip("=")
    params["signature"] = sig_b64

    with patch("app.services.ad_service._get_public_key", new_callable=AsyncMock) as mock_key:
        mock_key.return_value = public_key
        result = await verify_admob_ssv(params)
    assert result is True


@pytest.mark.asyncio
async def test_ad_reward_requires_auth():
    from httpx import AsyncClient, ASGITransport
    from app.main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/ad/reward")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_admob_ssv_invalid_signature_returns_400():
    """Geçersiz imzayla gelen SSV callback → 400."""
    from httpx import AsyncClient, ASGITransport
    from app.main import app

    # `from ... import verify_admob_ssv` ile alındığı için ad.py içindeki ismi patch'le
    with patch("app.api.v1.ad.verify_admob_ssv", new_callable=AsyncMock) as mock_verify:
        mock_verify.return_value = False
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/api/v1/ad/admob-ssv", params={
                "ad_unit_id": "test", "key_id": "1", "signature": "bad"
            })
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_admob_ssv_missing_user_id_returns_400():
    """İmza geçerli ama custom_data/user_id eksik → 400."""
    from httpx import AsyncClient, ASGITransport
    from app.main import app
    from app.core.dependencies import get_redis

    mock_redis = AsyncMock()

    async def override_redis():
        yield mock_redis

    app.dependency_overrides[get_redis] = override_redis
    try:
        with patch("app.api.v1.ad.verify_admob_ssv", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = True
            async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
                resp = await client.get("/api/v1/ad/admob-ssv", params={
                    "ad_unit_id": "test", "key_id": "1", "signature": "sig"
                })
        assert resp.status_code == 400
        assert "user_id" in resp.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_redis, None)


@pytest.mark.asyncio
async def test_admob_ssv_grants_bonus_on_valid_callback():
    """Geçerli SSV callback → Redis bonus verilir ve 200 döner."""
    import uuid
    from httpx import AsyncClient, ASGITransport
    from app.main import app
    from app.core.dependencies import get_redis

    user_id = str(uuid.uuid4())
    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=b"8")
    mock_redis.set = AsyncMock()
    mock_redis.expireat = AsyncMock()

    async def override_redis():
        yield mock_redis

    app.dependency_overrides[get_redis] = override_redis
    try:
        with patch("app.api.v1.ad.verify_admob_ssv", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = True
            async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
                resp = await client.get("/api/v1/ad/admob-ssv", params={
                    "key_id": "1", "signature": "sig", "custom_data": user_id
                })
        assert resp.status_code == 200
        assert resp.json()["ok"] is True
    finally:
        app.dependency_overrides.pop(get_redis, None)
