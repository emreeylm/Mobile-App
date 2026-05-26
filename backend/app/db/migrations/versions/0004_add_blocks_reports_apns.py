"""Add blocks, reports tables and APNs config support.

Revision ID: 0004
Revises: 0003
Create Date: 2026-05-20
"""
from alembic import op
import sqlalchemy as sa

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tbl_engellemeler",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("engelleyen_id", sa.Uuid, sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), nullable=False),
        sa.Column("engellenen_id", sa.Uuid, sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tarih", sa.TIMESTAMP, server_default=sa.func.now()),
    )
    op.create_index("ix_engellemeler_engelleyen", "tbl_engellemeler", ["engelleyen_id"])

    op.create_table(
        "tbl_raporlar",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("raporlayan_id", sa.Uuid, sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), nullable=False),
        sa.Column("raporlanan_id", sa.Uuid, sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sebep", sa.String(50), nullable=False),
        sa.Column("aciklama", sa.Text, nullable=True),
        sa.Column("tarih", sa.TIMESTAMP, server_default=sa.func.now()),
    )
    op.create_index("ix_raporlar_raporlayan", "tbl_raporlar", ["raporlayan_id"])


def downgrade() -> None:
    op.drop_index("ix_raporlar_raporlayan", "tbl_raporlar")
    op.drop_table("tbl_raporlar")
    op.drop_index("ix_engellemeler_engelleyen", "tbl_engellemeler")
    op.drop_table("tbl_engellemeler")
