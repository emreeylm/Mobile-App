"""Add password_hash to kullanicilar

Revision ID: 0002
Revises: 0001
Create Date: 2026-01-01 00:01:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tbl_kullanicilar",
        sa.Column("password_hash", sa.String(255), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tbl_kullanicilar", "password_hash")
