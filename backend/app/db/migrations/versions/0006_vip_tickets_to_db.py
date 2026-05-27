"""vip_tickets_to_db

VIP bilet bakiyesi Redis'ten PostgreSQL'e taşındı.
tbl_kullanicilar tablosuna vip_bilet_bakiye kolonu eklendi.

Revision ID: 0006
Revises: 9e6d52e560a9
Create Date: 2026-05-27
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0006"
down_revision: Union[str, None] = "9e6d52e560a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tbl_kullanicilar",
        sa.Column("vip_bilet_bakiye", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("tbl_kullanicilar", "vip_bilet_bakiye")
