import uuid
from pydantic import BaseModel


class VipBiletGonder(BaseModel):
    alici_id: uuid.UUID
    mesaj: str | None = None


class VipResponse(BaseModel):
    basarili: bool
    kalan_bilet: int
    eslesme_oldu: bool = False
