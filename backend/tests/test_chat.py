import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch
from app.main import app
from app.core.dependencies import get_current_user_id, get_db
from app.db.models import Eslesme, Engelleme, ChatMesaj

@pytest.fixture
def user_id() -> uuid.UUID:
    return uuid.uuid4()

@pytest.fixture
def other_id() -> uuid.UUID:
    return uuid.uuid4()

@pytest.mark.asyncio
async def test_chat_history_not_matched_returns_403(user_id, other_id):
    async def override_user():
        return user_id

    mock_db = AsyncMock()
    # Eşleşme yok -> return None for the first execute (blocking check), then None for matched check
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_result)

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_current_user_id] = override_user
    app.dependency_overrides[get_db] = override_db

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(f"/chat/{other_id}/messages")
        assert resp.status_code == 403
    finally:
        app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_chat_history_blocked_returns_403(user_id, other_id):
    async def override_user():
        return user_id

    mock_db = AsyncMock()
    # Engelleme var -> return a fake Engelleme object for the first query
    fake_block = MagicMock(spec=Engelleme)
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = fake_block
    mock_db.execute = AsyncMock(return_value=mock_result)

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_current_user_id] = override_user
    app.dependency_overrides[get_db] = override_db

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(f"/chat/{other_id}/messages")
        assert resp.status_code == 403
        assert "engelleme" in resp.json()["detail"]
    finally:
        app.dependency_overrides.clear()
