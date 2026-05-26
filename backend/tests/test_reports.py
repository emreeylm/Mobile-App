"""Block ve report endpoint testleri."""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_block_requires_auth():
    import uuid
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/reports/block", json={"hedef_id": str(uuid.uuid4())})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_report_requires_auth():
    import uuid
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/reports/report",
            json={"hedef_id": str(uuid.uuid4()), "sebep": "spam"},
        )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_report_invalid_reason():
    """Geçersiz sebep 422 döndürmeli."""
    import uuid
    from unittest.mock import AsyncMock
    from app.core.dependencies import get_current_user_id, get_db

    user_id = uuid.uuid4()
    mock_db = AsyncMock()

    async def override_user():
        return user_id

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_current_user_id] = override_user
    app.dependency_overrides[get_db] = override_db

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post(
                "/api/v1/reports/report",
                json={"hedef_id": str(uuid.uuid4()), "sebep": "gecersiz_sebep"},
            )
        assert resp.status_code == 422
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_block_self_returns_400():
    """Kendi kendini engellemeye çalışmak 400 döndürmeli."""
    import uuid
    from unittest.mock import AsyncMock
    from app.core.dependencies import get_current_user_id, get_db

    user_id = uuid.uuid4()
    mock_db = AsyncMock()

    async def override_user():
        return user_id

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_current_user_id] = override_user
    app.dependency_overrides[get_db] = override_db

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post(
                "/api/v1/reports/block",
                json={"hedef_id": str(user_id)},
            )
        assert resp.status_code == 400
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_device_token_requires_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post("/api/v1/notifications/device-token", json={"token": "abc123"})
    assert resp.status_code == 401
