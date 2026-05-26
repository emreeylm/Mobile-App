"""Add chat_mesajlari table and Eslesme indexes

Revision ID: 0003
Revises: 0002
Create Date: 2026-05-20 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tbl_chat_mesajlari",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("oda_id", sa.String(255), nullable=False),
        sa.Column(
            "gonderen_id",
            sa.Uuid(),
            sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("metin", sa.Text(), nullable=False),
        sa.Column(
            "tarih",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_chat_oda_id", "tbl_chat_mesajlari", ["oda_id"])
    op.create_index("ix_chat_oda_id_id", "tbl_chat_mesajlari", ["oda_id", "id"])

    op.create_index("ix_eslesmeler_gonderen_id", "tbl_eslesmeler", ["gonderen_id"])
    op.create_index("ix_eslesmeler_alici_durum", "tbl_eslesmeler", ["alici_id", "durum"])


def downgrade() -> None:
    op.drop_index("ix_eslesmeler_alici_durum", table_name="tbl_eslesmeler")
    op.drop_index("ix_eslesmeler_gonderen_id", table_name="tbl_eslesmeler")
    op.drop_index("ix_chat_oda_id_id", table_name="tbl_chat_mesajlari")
    op.drop_index("ix_chat_oda_id", table_name="tbl_chat_mesajlari")
    op.drop_table("tbl_chat_mesajlari")
