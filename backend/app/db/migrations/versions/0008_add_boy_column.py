"""Add boy and boy_gizli columns to tbl_kullanicilar

Revision ID: 0008
Revises: 0007
Create Date: 2026-05-28
"""
from typing import Union
from alembic import op

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        ALTER TABLE tbl_kullanicilar
        ADD COLUMN IF NOT EXISTS boy INTEGER
    """)
    op.execute("""
        ALTER TABLE tbl_kullanicilar
        ADD COLUMN IF NOT EXISTS boy_gizli BOOLEAN NOT NULL DEFAULT FALSE
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE tbl_kullanicilar DROP COLUMN IF EXISTS boy_gizli")
    op.execute("ALTER TABLE tbl_kullanicilar DROP COLUMN IF EXISTS boy")
