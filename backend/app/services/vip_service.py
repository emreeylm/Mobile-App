"""PostgreSQL tabanlı VIP bilet yönetimi.

Redis WATCH/MULTI/EXEC yerine PostgreSQL'in atomik UPDATE RETURNING kullanılır —
race condition riski yoktur ve consistent mod gerektirmez.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


async def get_balance(db: AsyncSession, user_id: str) -> int:
    """Kullanıcının mevcut VIP bilet bakiyesini döner."""
    result = await db.execute(
        text("SELECT vip_bilet_bakiye FROM tbl_kullanicilar WHERE id = :uid"),
        {"uid": user_id},
    )
    row = result.first()
    return row.vip_bilet_bakiye if row else 0


async def grant_welcome_ticket(db: AsyncSession, user_id: str) -> None:
    """Yeni kullanıcıya hoşgeldin bileti ver (yalnızca bakiye 0 ise set eder)."""
    await db.execute(
        text("""
            UPDATE tbl_kullanicilar
            SET vip_bilet_bakiye = 1
            WHERE id = :uid AND vip_bilet_bakiye = 0
        """),
        {"uid": user_id},
    )
    await db.commit()


async def consume_vip_ticket(db: AsyncSession, user_id: str) -> bool:
    """Bakiyeden 1 bilet düşür. Bakiye 0 ise False döner.

    PostgreSQL atomik UPDATE RETURNING ile race condition olmaksızın güvenlidir.
    """
    result = await db.execute(
        text("""
            UPDATE tbl_kullanicilar
            SET vip_bilet_bakiye = vip_bilet_bakiye - 1
            WHERE id = :user_id AND vip_bilet_bakiye > 0
            RETURNING vip_bilet_bakiye
        """),
        {"user_id": user_id},
    )
    await db.commit()
    return result.rowcount == 1


async def add_tickets(db: AsyncSession, user_id: str, count: int) -> int:
    """Satın alma sonrası bilet ekler. Yeni bakiye döner."""
    result = await db.execute(
        text("""
            UPDATE tbl_kullanicilar
            SET vip_bilet_bakiye = vip_bilet_bakiye + :count
            WHERE id = :uid
            RETURNING vip_bilet_bakiye
        """),
        {"uid": user_id, "count": count},
    )
    await db.commit()
    row = result.first()
    return row.vip_bilet_bakiye if row else 0
