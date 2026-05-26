import uuid
from datetime import datetime
from pydantic import BaseModel


class KoordinatSchema(BaseModel):
    lat: float
    lon: float


class KullaniciGuncelle(BaseModel):
    isim: str | None = None
    yas: int | None = None
    cinsiyet: str | None = None
    hedef_cinsiyet: str | None = None
    now_watching: str | None = None
    konum: KoordinatSchema | None = None


class KullaniciOlustur(BaseModel):
    email: str
    auth_provider: str
    provider_id: str
    isim: str
    yas: int
    cinsiyet: str
    hedef_cinsiyet: str


class KullaniciResponse(BaseModel):
    id: uuid.UUID
    email: str
    auth_provider: str
    isim: str
    yas: int
    cinsiyet: str
    hedef_cinsiyet: str
    now_watching: str | None
    is_premium: bool
    is_admin: bool = False   # Admin paneli için iOS tarafı bu alanı kullanır
    kayit_tarihi: datetime

    model_config = {"from_attributes": True}
