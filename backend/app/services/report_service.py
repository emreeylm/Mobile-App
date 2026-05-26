"""Kullanıcı engelleme ve raporlama servisi."""
import uuid
import logging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import Engelleme, Rapor

logger = logging.getLogger(__name__)


async def block_user(db: AsyncSession, engelleyen_id: uuid.UUID, engellenen_id: uuid.UUID) -> bool:
    """
    Kullanıcıyı engeller.
    Zaten engellenmiş ise True döner (idempotent).
    """
    async with db.begin():
        mevcut = await db.execute(
            select(Engelleme).where(
                Engelleme.engelleyen_id == engelleyen_id,
                Engelleme.engellenen_id == engellenen_id,
            )
        )
        if mevcut.scalar_one_or_none():
            return True
        db.add(Engelleme(engelleyen_id=engelleyen_id, engellenen_id=engellenen_id))
    logger.info("User %s blocked %s", engelleyen_id, engellenen_id)
    return True


async def report_user(
    db: AsyncSession,
    raporlayan_id: uuid.UUID,
    raporlanan_id: uuid.UUID,
    sebep: str,
    aciklama: str | None = None,
) -> None:
    """Kullanıcı şikayetini kaydeder."""
    async with db.begin():
        db.add(
            Rapor(
                raporlayan_id=raporlayan_id,
                raporlanan_id=raporlanan_id,
                sebep=sebep,
                aciklama=aciklama,
            )
        )
    logger.info("User %s reported %s (sebep=%s)", raporlayan_id, raporlanan_id, sebep)


async def is_blocked(db: AsyncSession, a_id: uuid.UUID, b_id: uuid.UUID) -> bool:
    """İki kullanıcı arasında herhangi bir yönde engelleme var mı?"""
    result = await db.execute(
        select(Engelleme).where(
            (
                (Engelleme.engelleyen_id == a_id) & (Engelleme.engellenen_id == b_id)
            ) | (
                (Engelleme.engelleyen_id == b_id) & (Engelleme.engellenen_id == a_id)
            )
        )
    )
    return result.scalar_one_or_none() is not None
