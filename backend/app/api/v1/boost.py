"""POST /boost — profil boost (30 dakika)"""
import uuid
from fastapi import APIRouter, Depends
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_redis

router = APIRouter(prefix="/boost", tags=["boost"])

BOOST_TTL = 30 * 60  # 30 dakika
BOOST_KEY = "user:boost:{user_id}"


@router.post("")
async def activate_boost(
    user_id: uuid.UUID = Depends(get_current_user_id),
    redis: Redis = Depends(get_redis),
):
    key = BOOST_KEY.format(user_id=str(user_id))
    await redis.setex(key, BOOST_TTL, "1")
    return {"active": True, "duration_seconds": BOOST_TTL}


@router.get("/status")
async def boost_status(
    user_id: uuid.UUID = Depends(get_current_user_id),
    redis: Redis = Depends(get_redis),
):
    key = BOOST_KEY.format(user_id=str(user_id))
    ttl = await redis.ttl(key)
    return {"active": ttl > 0, "remaining_seconds": max(0, ttl)}
