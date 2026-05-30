"""GET /likes — gelen beğeniler (blur mantığı)"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db
from app.db.models import Eslesme, Kullanici

router = APIRouter(prefix="/likes", tags=["likes"])


@router.get("")
async def get_likes(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Gelen beğenileri döner.
    Premium olmayan kullanıcılar için isim ve fotoğraf blur flag'i set edilir.
    """
    result = await db.execute(select(Kullanici).where(Kullanici.id == user_id))
    me = result.scalar_one_or_none()
    if not me:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Oturum geçersiz. Kullanıcı bulunamadı."
        )

    likes_q = await db.execute(
        select(Eslesme, Kullanici)
        .join(Kullanici, Kullanici.id == Eslesme.gonderen_id)
        .where(Eslesme.alici_id == user_id, Eslesme.durum.in_(["like", "vip_bilet"]))
        .order_by(Eslesme.tarih.desc())
    )
    rows = likes_q.all()

    data = []
    for eslesme, gonderen in rows:
        entry = {
            "id": str(gonderen.id),
            "yas": gonderen.yas,
            "tarih": eslesme.tarih.isoformat(),
            "blur": not me.is_premium,
        }
        if me.is_premium:
            entry["isim"] = gonderen.isim
            entry["now_watching"] = gonderen.now_watching
            entry["durum"] = eslesme.durum
            entry["mesaj"] = eslesme.mesaj
        else:
            entry["isim"] = None
            entry["now_watching"] = None
            entry["durum"] = "like"   # VIP bilet bilgisini non-premium'dan gizle
            entry["mesaj"] = None
        data.append(entry)

    return {"likes": data}
