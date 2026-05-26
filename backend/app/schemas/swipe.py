import uuid
from pydantic import BaseModel


class SwipeRequest(BaseModel):
    hedef_id: uuid.UUID
    yon: str  # 'like' | 'dislike'


class SwipeResponse(BaseModel):
    basarili: bool
    eslesme_oldu: bool
    kalan_hak: int | None = None
