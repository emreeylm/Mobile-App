"""POST /swipes + DELETE /swipes/last — Redis kota kontrolü + eşleşme tespiti + rewind"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_db, get_redis
from app.db.models import Eslesme, Kullanici
from app.schemas.swipe import SwipeRequest, SwipeResponse
from app.services import swipe_service, notification_service

router = APIRouter(prefix="/swipes", tags=["swipes"])


@router.post("", response_model=SwipeResponse)
async def swipe(
    body: SwipeRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    # Kota yalnızca sağ kaydırma (like) için uygulanır — sol kaydırma (dislike) kotadan düşmez
    me = await db.get(Kullanici, user_id)
    if me and me.is_premium:
        kalan = 999
    elif body.yon == "like":
        izin_var, kalan = await swipe_service.check_and_increment_swipe(redis, str(user_id))
        if not izin_var:
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Günlük beğeni limitine ulaşıldı")
    else:
        # dislike — kota sayılmaz; kalan beğeni sayısını bilgi amaçlı hesapla
        kalan = await swipe_service.get_remaining(redis, str(user_id))

    eslesme_oldu = False
    gonderen_isim = ""
    async with db.begin():
        db.add(Eslesme(gonderen_id=user_id, alici_id=body.hedef_id, durum=body.yon))

        if body.yon == "like":
            result = await db.execute(
                select(Eslesme).where(
                    Eslesme.gonderen_id == body.hedef_id,
                    Eslesme.alici_id == user_id,
                    Eslesme.durum.in_(["like", "vip_bilet"]),
                )
            )
            if result.scalar_one_or_none():
                eslesme_oldu = True

            if eslesme_oldu:
                gonderen = await db.get(Kullanici, user_id)
                gonderen_isim = gonderen.isim if gonderen else "Biri"

    if eslesme_oldu:
        await notification_service.notify_new_match(redis, str(body.hedef_id), gonderen_isim)

    return SwipeResponse(basarili=True, eslesme_oldu=eslesme_oldu, kalan_hak=kalan)


@router.delete("/last")
async def rewind_last_swipe(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """
    Son dislike swipe'ı geri alır (Rewind). Yalnızca premium kullanıcılara açık.
    İlgili Eslesme kaydını siler ve Redis swipe sayacını 1 azaltır.
    """
    me = await db.get(Kullanici, user_id)
    if not me or not me.is_premium:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Rewind yalnızca premium üyelere açıktır")

    async with db.begin():
        result = await db.execute(
            select(Eslesme)
            .where(Eslesme.gonderen_id == user_id, Eslesme.durum == "dislike")
            .order_by(Eslesme.tarih.desc())
            .limit(1)
        )
        last_swipe = result.scalar_one_or_none()
        if last_swipe is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Geri alınacak swipe bulunamadı")

        rewound_user_id = str(last_swipe.alici_id)
        await db.execute(delete(Eslesme).where(Eslesme.id == last_swipe.id))

    # Swipe sayacını 1 geri al (premium için yalnızca istatistik amaçlı)
    await swipe_service.decrement_swipe(redis, str(user_id))

    return {"basarili": True, "geri_alinan_kullanici_id": rewound_user_id}
