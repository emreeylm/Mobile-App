"""Initial schema

Revision ID: 0001
Revises:
Create Date: 2026-01-01 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
import geoalchemy2

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "tbl_kullanicilar",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("email", sa.String(255), unique=True, nullable=False),
        sa.Column("auth_provider", sa.String(50), nullable=False),
        sa.Column("provider_id", sa.String(255), unique=True, nullable=False),
        sa.Column("isim", sa.String(100), nullable=False),
        sa.Column("yas", sa.Integer(), nullable=False),
        sa.Column("cinsiyet", sa.String(20), nullable=False),
        sa.Column("hedef_cinsiyet", sa.String(20), nullable=False),
        sa.Column("konum", geoalchemy2.Geometry("POINT", srid=4326), nullable=True),
        sa.Column("now_watching", sa.String(255), nullable=True),
        sa.Column("is_premium", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("kayit_tarihi", sa.DateTime(), server_default=sa.text("NOW()")),
    )
    op.create_index("idx_kullanicilar_konum", "tbl_kullanicilar", ["konum"], postgresql_using="gist")

    op.create_table(
        "tbl_medya",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("baslik", sa.String(255), nullable=False),
        sa.Column("tip", sa.String(20), nullable=False),
        sa.Column("afis_url", sa.String(255), nullable=True),
    )

    op.create_table(
        "tbl_kullanici_medya",
        sa.Column("kullanici_id", sa.Uuid(), sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("medya_id", sa.Integer(), sa.ForeignKey("tbl_medya.id", ondelete="CASCADE"), primary_key=True),
    )

    op.create_table(
        "tbl_eslesmeler",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("gonderen_id", sa.Uuid(), sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE")),
        sa.Column("alici_id", sa.Uuid(), sa.ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE")),
        sa.Column("durum", sa.String(20), nullable=False),
        sa.Column("mesaj", sa.Text(), nullable=True),
        sa.Column("tarih", sa.DateTime(), server_default=sa.text("NOW()")),
    )


def downgrade() -> None:
    op.drop_table("tbl_eslesmeler")
    op.drop_table("tbl_kullanici_medya")
    op.drop_table("tbl_medya")
    op.drop_index("idx_kullanicilar_konum", table_name="tbl_kullanicilar")
    op.drop_table("tbl_kullanicilar")
