"""POST /reports/block, POST /reports/report, GET /admin/reports — Engelleme ve şikayet"""
import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db
from app.db.models import Kullanici, Rapor
from app.services import report_service

router = APIRouter(prefix="/reports", tags=["reports"])

VALID_REASONS = {"spam", "uygunsuz_icerik", "taciz", "sahte_profil", "diger"}


class BlockRequest(BaseModel):
    hedef_id: uuid.UUID


class ReportRequest(BaseModel):
    hedef_id: uuid.UUID
    sebep: str
    aciklama: str | None = None


@router.post("/block", status_code=204)
async def block_user(
    body: BlockRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Hedef kullanıcıyı engeller."""
    if body.hedef_id == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kendinizi engelleyemezsiniz")
    await report_service.block_user(db, user_id, body.hedef_id)


@router.post("/report", status_code=204)
async def report_user(
    body: ReportRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Hedef kullanıcıyı raporlar."""
    if body.hedef_id == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kendinizi raporlayamazsınız")
    if body.sebep not in VALID_REASONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Geçersiz sebep. Seçenekler: {', '.join(VALID_REASONS)}",
        )
    await report_service.report_user(db, user_id, body.hedef_id, body.sebep, body.aciklama)


# ---------------------------------------------------------------------------
# Admin endpoint — sadece is_admin=True kullanıcılar erişebilir
# ---------------------------------------------------------------------------

class RaporResponse(BaseModel):
    id: int
    raporlayan_id: uuid.UUID
    raporlanan_id: uuid.UUID
    sebep: str
    aciklama: str | None
    tarih: datetime

    model_config = {"from_attributes": True}


async def _require_admin(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> uuid.UUID:
    """Admin yetkisi kontrolü; yetkisiz erişimde 403 döner."""
    result = await db.execute(select(Kullanici).where(Kullanici.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin yetkisi gerekli")
    return user_id


@router.get("/admin", response_model=list[RaporResponse], tags=["admin"])
async def list_reports(
    skip: int = 0,
    limit: int = 50,
    sebep: str | None = None,
    admin_id: uuid.UUID = Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Tüm raporları listeler. Sadece admin kullanıcılar erişebilir.
    Opsiyonel sebep filtresi: ?sebep=spam
    """
    q = select(Rapor).order_by(Rapor.tarih.desc()).offset(skip).limit(limit)
    if sebep:
        q = q.where(Rapor.sebep == sebep)
    result = await db.execute(q)
    return result.scalars().all()
