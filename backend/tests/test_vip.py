"""VIP bilet tüketim testleri."""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.vip_service import consume_vip_ticket


def _make_pipe_mock(balance: int, should_raise: bool = False):
    """WATCH/MULTI/EXEC pipeline mock'u üretir."""
    from redis.exceptions import WatchError
    pipe = AsyncMock()
    pipe.__aenter__ = AsyncMock(return_value=pipe)
    pipe.__aexit__ = AsyncMock(return_value=None)
    pipe.watch = AsyncMock()
    pipe.multi = MagicMock()
    pipe.decr = MagicMock()
    # vip_service `await pipe.get(key)` çağırır; balance değerini döndür
    pipe.get = AsyncMock(return_value=str(balance).encode() if balance > 0 else b"0")

    if should_raise:
        call_count = [0]
        async def execute_side_effect():
            call_count[0] += 1
            if call_count[0] == 1:
                raise WatchError()
            return [balance - 1]
        pipe.execute = execute_side_effect
    else:
        pipe.execute = AsyncMock(return_value=[balance - 1])

    redis = AsyncMock()
    redis.pipeline = MagicMock(return_value=pipe)
    return redis, pipe


@pytest.mark.asyncio
async def test_consume_ticket_success():
    redis, pipe = _make_pipe_mock(balance=3)
    result = await consume_vip_ticket(redis, "user-1")
    assert result is True


@pytest.mark.asyncio
async def test_consume_ticket_zero_balance():
    redis, pipe = _make_pipe_mock(balance=0)
    result = await consume_vip_ticket(redis, "user-1")
    assert result is False


@pytest.mark.asyncio
async def test_vip_endpoint_requires_auth():
    import uuid
    from httpx import AsyncClient, ASGITransport
    from app.main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/vip/send", json={"alici_id": str(uuid.uuid4()), "mesaj": None})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_vip_balance_requires_auth():
    from httpx import AsyncClient, ASGITransport
    from app.main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/vip/balance")
    assert resp.status_code == 401
