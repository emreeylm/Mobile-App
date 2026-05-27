"""POST /vip/send — VIP bilet gönderme"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_db, get_redis
from app.db.models import Eslesme, Kullanici
from app.schemas.vip import VipBiletGonder, VipResponse
from app.services import vip_service, notification_service

router = APIRouter(prefix="/vip", tags=["vip"])


@router.post("/send", response_model=VipResponse)
async def send_vip_ticket(
    body: VipBiletGonder,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    # Bakiyeden bilet düş (atomik PostgreSQL UPDATE)
    consumed = await vip_service.consume_vip_ticket(db, str(user_id))
    if not consumed:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Yeterli VIP bilet yok")

    eslesme_oldu = False
    gonderen_isim = ""
    async with db.begin():
        result = await db.execute(
            select(Eslesme).where(
                Eslesme.gonderen_id == body.alici_id,
                Eslesme.alici_id == user_id,
                Eslesme.durum.in_(["like", "vip_bilet"]),
            )
        )
        if result.scalar_one_or_none():
            eslesme_oldu = True

        db.add(Eslesme(
            gonderen_id=user_id,
            alici_id=body.alici_id,
            durum="vip_bilet",
            mesaj=body.mesaj,
        ))

        if eslesme_oldu:
            gonderen = await db.get(Kullanici, user_id)
            gonderen_isim = gonderen.isim if gonderen else "Biri"

    if eslesme_oldu:
        await notification_service.notify_new_match(redis, str(body.alici_id), gonderen_isim)

    kalan = await vip_service.get_balance(db, str(user_id))
    return VipResponse(basarili=True, kalan_bilet=kalan, eslesme_oldu=eslesme_oldu)


@router.get("/balance")
async def get_balance(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return {"balance": await vip_service.get_balance(db, str(user_id))}
