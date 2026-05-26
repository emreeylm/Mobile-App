"""GET /matches — karşılıklı eşleşmeler"""
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db
from app.db.models import Eslesme, Kullanici

router = APIRouter(prefix="/matches", tags=["matches"])


@router.get("")
async def get_matches(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Karşılıklı 'like' olan eşleşmeleri döner."""
    sent = select(Eslesme.alici_id).where(
        Eslesme.gonderen_id == user_id, Eslesme.durum == "like"
    )
    result = await db.execute(
        select(Kullanici)
        .join(Eslesme, and_(Eslesme.gonderen_id == Kullanici.id, Eslesme.alici_id == user_id, Eslesme.durum == "like"))
        .where(Kullanici.id.in_(sent))
    )
    eslesmeler = result.scalars().all()
    return {
        "matches": [
            {"id": str(k.id), "isim": k.isim, "yas": k.yas, "now_watching": k.now_watching}
            for k in eslesmeler
        ]
    }
