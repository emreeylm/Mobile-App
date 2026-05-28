"""Add telefon column and make email nullable for phone OTP auth

Revision ID: 0007
Revises: 0006
Create Date: 2026-05-28
"""
from typing import Union
import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # telefon kolonu ekle (E.164 formatında, ör: +905xxxxxxxxx)
    op.add_column(
        "tbl_kullanicilar",
        sa.Column("telefon", sa.String(20), nullable=True),
    )
    op.create_unique_constraint("uq_kullanicilar_telefon", "tbl_kullanicilar", ["telefon"])

    # email'i nullable yap (telefon auth kullananların email'i olmaz)
    op.alter_column("tbl_kullanicilar", "email", nullable=True)


def downgrade() -> None:
    op.alter_column("tbl_kullanicilar", "email", nullable=False)
    op.drop_constraint("uq_kullanicilar_telefon", "tbl_kullanicilar", type_="unique")
    op.drop_column("tbl_kullanicilar", "telefon")
