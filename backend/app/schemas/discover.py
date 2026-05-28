import uuid
from pydantic import BaseModel


class DiscoverKullanici(BaseModel):
    id: uuid.UUID
    isim: str
    yas: int
    now_watching: str | None
    uyumluluk_skoru: int
    foto_url: str | None = None       # İlk profil fotoğrafı URL'si (S3 veya local)
    ortak_medya: list[str] = []       # Ortak medya başlıkları (en fazla 3)
    boy: int | None = None            # boy_gizli=True ise None döner

    model_config = {"from_attributes": True}


class DiscoverResponse(BaseModel):
    kullanicilar: list[DiscoverKullanici]
