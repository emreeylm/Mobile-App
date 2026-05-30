"""add okundu column to tbl_chat_mesajlari

Revision ID: 0009
Revises: 9e6d52e560a9
Create Date: 2026-05-30
"""
from alembic import op
import sqlalchemy as sa

revision = "0009"
down_revision = "9e6d52e560a9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tbl_chat_mesajlari",
        sa.Column("okundu", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("tbl_chat_mesajlari", "okundu")
