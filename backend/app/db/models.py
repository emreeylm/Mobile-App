import uuid
from datetime import datetime, timezone
from geoalchemy2 import Geometry
from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.session import Base


class Kullanici(Base):
    __tablename__ = "tbl_kullanicilar"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    # DEPRECATED (2026-05): telefon OTP auth kaldırıldı. Kolon backward compat için tutuluyor.
    telefon: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    auth_provider: Mapped[str] = mapped_column(String(50), nullable=False)  # 'apple' | 'google'
    provider_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    isim: Mapped[str] = mapped_column(String(100), nullable=False)
    yas: Mapped[int] = mapped_column(Integer, nullable=False)
    cinsiyet: Mapped[str] = mapped_column(String(20), nullable=False)
    hedef_cinsiyet: Mapped[str] = mapped_column(String(20), nullable=False)
    konum = mapped_column(Geometry("POINT", srid=4326), nullable=True)
    now_watching: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    kayit_tarihi: Mapped[datetime] = mapped_column(server_default=func.now())
    turler: Mapped[str | None] = mapped_column(String(512), nullable=True)
    vip_bilet_bakiye: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    boy: Mapped[int | None] = mapped_column(Integer, nullable=True)              # cm cinsinden boy (opsiyonel)
    boy_gizli: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)  # True → profilinde gösterilmez

    medyalar: Mapped[list["KullaniciMedya"]] = relationship(back_populates="kullanici", cascade="all, delete-orphan")


class Medya(Base):
    __tablename__ = "tbl_medya"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)  # TMDB ID
    baslik: Mapped[str] = mapped_column(String(255), nullable=False)
    tip: Mapped[str] = mapped_column(String(20), nullable=False)  # 'movie' | 'tv'
    afis_url: Mapped[str | None] = mapped_column(String(255), nullable=True)


class KullaniciMedya(Base):
    __tablename__ = "tbl_kullanici_medya"

    kullanici_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), primary_key=True)
    medya_id: Mapped[int] = mapped_column(Integer, ForeignKey("tbl_medya.id", ondelete="CASCADE"), primary_key=True)

    kullanici: Mapped["Kullanici"] = relationship(back_populates="medyalar")
    medya: Mapped["Medya"] = relationship()


class Eslesme(Base):
    __tablename__ = "tbl_eslesmeler"
    __table_args__ = (
        Index("ix_eslesmeler_gonderen_id", "gonderen_id"),
        Index("ix_eslesmeler_alici_durum", "alici_id", "durum"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    gonderen_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    alici_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    durum: Mapped[str] = mapped_column(String(20), nullable=False)  # 'like' | 'dislike' | 'vip_bilet'
    mesaj: Mapped[str | None] = mapped_column(Text, nullable=True)
    tarih: Mapped[datetime] = mapped_column(server_default=func.now())


class Engelleme(Base):
    __tablename__ = "tbl_engellemeler"
    __table_args__ = (
        Index("ix_engellemeler_engelleyen", "engelleyen_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    engelleyen_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    engellenen_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    tarih: Mapped[datetime] = mapped_column(server_default=func.now())


class Rapor(Base):
    __tablename__ = "tbl_raporlar"
    __table_args__ = (
        Index("ix_raporlar_raporlayan", "raporlayan_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    raporlayan_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    raporlanan_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"))
    sebep: Mapped[str] = mapped_column(String(50), nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    tarih: Mapped[datetime] = mapped_column(server_default=func.now())


class ChatMesaj(Base):
    __tablename__ = "tbl_chat_mesajlari"
    __table_args__ = (
        Index("ix_chat_oda_id", "oda_id"),
        Index("ix_chat_oda_id_id", "oda_id", "id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    oda_id: Mapped[str] = mapped_column(String(255), nullable=False)
    gonderen_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("tbl_kullanicilar.id", ondelete="CASCADE"), nullable=False
    )
    metin: Mapped[str] = mapped_column(Text, nullable=False)
    tarih: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    okundu: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
