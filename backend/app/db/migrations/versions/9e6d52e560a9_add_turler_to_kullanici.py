"""add_turler_to_kullanici

Revision ID: 9e6d52e560a9
Revises: 0005
Create Date: 2026-05-24 16:26:10.051226

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '9e6d52e560a9'
down_revision: Union[str, None] = '0005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('tbl_kullanicilar', sa.Column('turler', sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column('tbl_kullanicilar', 'turler')
