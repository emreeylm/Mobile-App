"""GET /discover — eşleşme algoritması"""
import uuid
from fastapi import APIRouter, Depends, Query, HTTPException, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db, get_redis
from app.db.models import Kullanici
from app.schemas.discover import DiscoverResponse
from app.services import discover_service
from sqlalchemy import select

router = APIRouter(prefix="/discover", tags=["discover"])


@router.get("", response_model=DiscoverResponse)
async def discover(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    global_mod: bool = Query(False),
    min_age: int | None = Query(None, ge=18, le=99),
    max_age: int | None = Query(None, ge=18, le=99),
    max_distance_km: int | None = Query(None, ge=1, le=20000),
    min_boy: int | None = Query(None, ge=100, le=250),
    max_boy: int | None = Query(None, ge=100, le=250),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    result = await db.execute(select(Kullanici).where(Kullanici.id == user_id))
    me = result.scalar_one_or_none()
    if not me:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Oturum geçersiz. Kullanıcı bulunamadı."
        )

    kullanicilar = await discover_service.get_discover_feed(
        db=db,
        user_id=user_id,
        user_lat=lat,
        user_lon=lon,
        user_yas=me.yas,
        istenen_cinsiyet=me.hedef_cinsiyet,
        is_premium=me.is_premium,
        global_mod=global_mod,
        min_age_override=min_age if me.is_premium else None,
        max_age_override=max_age if me.is_premium else None,
        max_distance_km_override=max_distance_km if me.is_premium else None,
        min_boy_override=min_boy if me.is_premium else None,
        max_boy_override=max_boy if me.is_premium else None,
    )

    # Boost aktif olan kullanıcıları sıranın başına al
    if kullanicilar:
        boost_checks = await _get_boosted_ids(redis, [str(k["id"]) for k in kullanicilar])
        kullanicilar.sort(key=lambda k: (0 if str(k["id"]) in boost_checks else 1, -k["uyumluluk_skoru"]))

    return DiscoverResponse(kullanicilar=kullanicilar)


async def _get_boosted_ids(redis: Redis, user_ids: list[str]) -> set[str]:
    """Redis pipeline ile boost key'i olan kullanıcı ID'lerini döner (tek roundtrip)."""
    if not user_ids:
        return set()
    pipe = redis.pipeline()
    for uid in user_ids:
        pipe.exists(f"user:boost:{uid}")
    results = await pipe.execute()
    return {uid for uid, exists in zip(user_ids, results) if exists}
