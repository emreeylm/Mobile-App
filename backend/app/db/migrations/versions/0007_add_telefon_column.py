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
    # telefon kolonu ekle (IF NOT EXISTS — idempotent)
    op.execute("""
        ALTER TABLE tbl_kullanicilar
        ADD COLUMN IF NOT EXISTS telefon VARCHAR(20)
    """)

    # unique constraint ekle (yoksa)
    op.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints
                WHERE constraint_name = 'uq_kullanicilar_telefon'
                  AND table_name = 'tbl_kullanicilar'
            ) THEN
                ALTER TABLE tbl_kullanicilar
                ADD CONSTRAINT uq_kullanicilar_telefon UNIQUE (telefon);
            END IF;
        END $$
    """)

    # email nullable yap (DROP NOT NULL — zaten nullable ise no-op)
    op.execute("""
        ALTER TABLE tbl_kullanicilar
        ALTER COLUMN email DROP NOT NULL
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE tbl_kullanicilar ALTER COLUMN email SET NOT NULL")
    op.execute("""
        ALTER TABLE tbl_kullanicilar
        DROP CONSTRAINT IF EXISTS uq_kullanicilar_telefon
    """)
    op.drop_column("tbl_kullanicilar", "telefon")
