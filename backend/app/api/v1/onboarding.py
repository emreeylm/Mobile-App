"""POST /onboarding — medya seçimi validasyonu ve kaydı"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, model_validator
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db
from app.db.models import KullaniciMedya, Medya, Kullanici
from app.services import vip_service

router = APIRouter(prefix="/onboarding", tags=["onboarding"])


class MedyaItem(BaseModel):
    id: int
    baslik: str
    tip: str  # 'movie' | 'tv'
    afis_url: str | None = None


class OnboardingRequest(BaseModel):
    diziler: list[MedyaItem]
    filmler: list[MedyaItem]
    turler: list[str]

    @model_validator(mode="after")
    def validate_limits(self):
        if len(self.diziler) < 5:
            raise ValueError("En az 5 dizi seçilmeli")
        if len(self.filmler) < 5:
            raise ValueError("En az 5 film seçilmeli")
        if len(self.turler) < 3:
            raise ValueError("En az 3 tür seçilmeli")
        if len(self.diziler) + len(self.filmler) > 20:
            raise ValueError("Toplam yapım sayısı 20'yi geçemez")
        return self


@router.post("")
async def save_onboarding(
    body: OnboardingRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    all_media = [(m, "tv") for m in body.diziler] + [(m, "movie") for m in body.filmler]

    async with db.begin():
        user = await db.get(Kullanici, user_id)
        if user:
            user.turler = ",".join(body.turler)

        for item, tip in all_media:
            medya = await db.get(Medya, item.id)
            if not medya:
                medya = Medya(id=item.id, baslik=item.baslik, tip=tip, afis_url=item.afis_url)
                db.add(medya)
            await db.flush()
            km = KullaniciMedya(kullanici_id=user_id, medya_id=item.id)
            await db.merge(km)

    # Hoş geldin hediyesi: ilk onboarding'de 1 VIP bilet (WHERE bakiye=0 → idempotent)
    await vip_service.grant_welcome_ticket(db, str(user_id))

    return {"status": "ok", "medya_count": len(all_media), "welcome_vip_ticket": 1}
