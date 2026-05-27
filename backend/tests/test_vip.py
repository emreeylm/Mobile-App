"""VIP bilet tüketim testleri (PostgreSQL tabanlı)."""
import uuid
import pytest
from unittest.mock import AsyncMock, MagicMock
from sqlalchemy.ext.asyncio import AsyncSession
from app.services.vip_service import consume_vip_ticket, get_balance, add_tickets


def _make_db(rowcount: int = 1, balance: int = 0) -> AsyncMock:
    """AsyncSession mock'u — consume/get_balance/add_tickets için."""
    db = AsyncMock(spec=AsyncSession)

    execute_result = MagicMock()
    execute_result.rowcount = rowcount
    first_row = MagicMock()
    first_row.vip_bilet_bakiye = balance
    execute_result.first.return_value = first_row

    db.execute = AsyncMock(return_value=execute_result)
    db.commit = AsyncMock()
    return db


@pytest.mark.asyncio
async def test_consume_ticket_success():
    """Bakiye > 0 → bilet tüketilir, True döner."""
    db = _make_db(rowcount=1)
    result = await consume_vip_ticket(db, str(uuid.uuid4()))
    assert result is True
    db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_consume_ticket_zero_balance():
    """Bakiye 0 → rowcount=0 → False döner."""
    db = _make_db(rowcount=0)
    result = await consume_vip_ticket(db, str(uuid.uuid4()))
    assert result is False


@pytest.mark.asyncio
async def test_get_balance_returns_value():
    """get_balance → DB'den bakiyeyi döner."""
    db = _make_db(balance=3)
    result = await get_balance(db, str(uuid.uuid4()))
    assert result == 3


@pytest.mark.asyncio
async def test_add_tickets_returns_new_balance():
    """add_tickets → yeni bakiyeyi döner."""
    db = _make_db(balance=5)
    result = await add_tickets(db, str(uuid.uuid4()), count=2)
    assert result == 5
    db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_vip_endpoint_requires_auth():
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=__import__("app.main", fromlist=["app"]).app),
        base_url="http://test"
    ) as client:
        resp = await client.post("/api/v1/vip/send", json={"alici_id": str(uuid.uuid4()), "mesaj": None})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_vip_balance_requires_auth():
    async with __import__("httpx").AsyncClient(
        transport=__import__("httpx").ASGITransport(app=__import__("app.main", fromlist=["app"]).app),
        base_url="http://test"
    ) as client:
        resp = await client.get("/api/v1/vip/balance")
    assert resp.status_code == 401
