"""Swipe kota ve reklam bonus testleri."""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.swipe_service import check_and_increment_swipe, grant_ad_bonus, DAILY_LIMIT, AD_BONUS


def _make_redis(current_count: int | None):
    """Verilen sayım değeriyle Redis mock'u üretir."""
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=str(current_count).encode() if current_count is not None else None)
    redis.incr = AsyncMock(return_value=(current_count or 0) + 1)
    redis.expireat = AsyncMock()
    redis.incrby = AsyncMock(return_value=(current_count or 0) + AD_BONUS)

    pipe = AsyncMock()
    pipe.__aenter__ = AsyncMock(return_value=pipe)
    pipe.__aexit__ = AsyncMock(return_value=None)
    pipe.watch = AsyncMock()
    pipe.multi = MagicMock()
    async def dynamic_get(key):
        return await redis.get(key)
    pipe.get = AsyncMock(side_effect=dynamic_get)
    pipe.incr = MagicMock()
    pipe.expireat = MagicMock()
    pipe.execute = AsyncMock(return_value=[(current_count or 0) + 1, True])
    redis.pipeline = MagicMock(return_value=pipe)

    return redis


@pytest.mark.asyncio
async def test_first_swipe_is_allowed():
    redis = _make_redis(None)
    allowed, remaining = await check_and_increment_swipe(redis, "user-1")
    assert allowed is True
    redis.pipeline.return_value.incr.assert_called_once()


@pytest.mark.asyncio
async def test_swipe_within_limit():
    redis = _make_redis(5)
    allowed, remaining = await check_and_increment_swipe(redis, "user-1")
    assert allowed is True


@pytest.mark.asyncio
async def test_swipe_at_exact_limit_blocked():
    redis = _make_redis(DAILY_LIMIT)
    allowed, remaining = await check_and_increment_swipe(redis, "user-1")
    assert allowed is False
    redis.incr.assert_not_called()


@pytest.mark.asyncio
async def test_swipe_over_limit_blocked():
    redis = _make_redis(DAILY_LIMIT + 3)
    allowed, _ = await check_and_increment_swipe(redis, "user-1")
    assert allowed is False


@pytest.mark.asyncio
async def test_ad_bonus_increases_quota():
    redis = _make_redis(DAILY_LIMIT)
    redis.set = AsyncMock()
    redis.expireat = AsyncMock()
    new_remaining = await grant_ad_bonus(redis, "user-1")
    redis.set.assert_called_once()
    assert new_remaining >= 0


@pytest.mark.asyncio
async def test_swipe_endpoint_returns_429_on_limit():
    from httpx import AsyncClient, ASGITransport
    from app.main import app
    from app.core.dependencies import get_current_user_id, get_redis, get_db
    import uuid

    user_id = uuid.uuid4()
    mock_redis = AsyncMock()
    mock_db = AsyncMock()

    # Premium bypass'ı engellemek için is_premium=False olan kullanıcı döndür
    free_user = MagicMock()
    free_user.is_premium = False
    mock_db.get = AsyncMock(return_value=free_user)
    ctx = MagicMock()
    ctx.__aenter__ = AsyncMock(return_value=None)
    ctx.__aexit__ = AsyncMock(return_value=None)
    mock_db.begin = MagicMock(return_value=ctx)
    mock_db.add = MagicMock()
    mock_db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None)
    ))

    async def override_user():
        return user_id

    async def override_redis():
        yield mock_redis

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_current_user_id] = override_user
    app.dependency_overrides[get_redis] = override_redis
    app.dependency_overrides[get_db] = override_db

    try:
        with patch("app.services.swipe_service.check_and_increment_swipe", new_callable=AsyncMock) as mock_swipe:
            mock_swipe.return_value = (False, 0)
            async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
                resp = await client.post(
                    "/api/v1/swipes",
                    json={"hedef_id": str(uuid.uuid4()), "yon": "like"},
                )
        assert resp.status_code == 429
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
        app.dependency_overrides.pop(get_redis, None)
        app.dependency_overrides.pop(get_db, None)
