"""POST /notifications/device-token — APNs cihaz token kaydı"""
import uuid
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_redis
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


class DeviceTokenRequest(BaseModel):
    token: str


@router.post("/device-token", status_code=204)
async def register_device_token(
    body: DeviceTokenRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    redis: Redis = Depends(get_redis),
):
    """Kullanıcının APNs cihaz token'ını kaydeder."""
    await notification_service.save_device_token(redis, str(user_id), body.token)
