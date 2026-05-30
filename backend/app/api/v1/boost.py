"""POST /boost — profil boost (30 dakika, yalnızca premium)"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_redis, get_db
from app.db.models import Kullanici

router = APIRouter(prefix="/boost", tags=["boost"])

BOOST_TTL = 30 * 60  # 30 dakika
BOOST_KEY = "user:boost:{user_id}"


@router.post("")
async def activate_boost(
    user_id: uuid.UUID = Depends(get_current_user_id),
    redis: Redis = Depends(get_redis),
    db: AsyncSession = Depends(get_db),
):
    me = await db.get(Kullanici, user_id)
    if not me or not me.is_premium:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Boost özelliği yalnızca premium üyelere açıktır",
        )
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
