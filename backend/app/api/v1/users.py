"""GET/PATCH /users/me + POST /users/me/photos"""
import uuid
import os
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.responses import FileResponse
from geoalchemy2.functions import ST_SetSRID, ST_MakePoint
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user_id, get_db
from app.core.config import settings
from app.db.models import Kullanici
from app.schemas.user import KullaniciGuncelle, KullaniciResponse
from app.services import storage_service

router = APIRouter(prefix="/users", tags=["users"])

_LOCAL_UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/tmp/bingedate_photos"))
_LOCAL_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
_MAX_PHOTO_BYTES = 8 * 1024 * 1024  # 8 MB
_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}


async def _get_or_404(db: AsyncSession, user_id: uuid.UUID) -> Kullanici:
    result = await db.execute(select(Kullanici).where(Kullanici.id == user_id))
    k = result.scalar_one_or_none()
    if not k:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return k


@router.get("/me", response_model=KullaniciResponse)
async def get_me(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await _get_or_404(db, user_id)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcı hesabını ve tüm ilgili verileri kalıcı olarak siler.
    Eşleşmeler, mesajlar, medya bağlantıları CASCADE ile otomatik silinir.
    Apple App Store zorunluluğu (iOS 15.4+).
    """
    async with db.begin():
        k = await _get_or_404(db, user_id)
        await db.delete(k)


@router.patch("/me", response_model=KullaniciResponse)
async def update_me(
    body: KullaniciGuncelle,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    async with db.begin():
        k = await _get_or_404(db, user_id)
        if body.isim is not None:
            k.isim = body.isim
        if body.yas is not None:
            if body.yas < 18:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Yaş en az 18 olmalıdır.",
                )
            k.yas = body.yas
        if body.cinsiyet is not None:
            k.cinsiyet = body.cinsiyet
        if body.hedef_cinsiyet is not None:
            k.hedef_cinsiyet = body.hedef_cinsiyet
        if body.now_watching is not None:
            k.now_watching = body.now_watching
        if body.konum is not None:
            k.konum = ST_SetSRID(ST_MakePoint(body.konum.lon, body.konum.lat), 4326)
    return k


@router.post("/me/photos")
async def upload_photo(
    file: UploadFile = File(...),
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    """
    Profil fotoğrafı yükler. Dosyayı sunucu diskine kaydeder ve erişim URL'si döner.
    Üretimde bu endpoint S3/GCS'e yönlendirilmelidir.
    """
    content_type = file.content_type or ""
    if content_type not in _ALLOWED_MIME:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Desteklenmeyen dosya türü: {content_type}. JPEG/PNG/WebP kullanın.",
        )

    data = await file.read()
    if len(data) > _MAX_PHOTO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Dosya boyutu 8 MB limitini aşıyor",
        )

    filename = storage_service.make_filename(str(user_id), data, content_type)
    photo_id = filename.split("_")[-1].rsplit(".", 1)[0]

    url = await storage_service.upload_file(data=data, filename=filename, content_type=content_type)
    return {"url": url, "photo_id": photo_id}


@router.get("/photos/{filename}")
async def serve_photo(filename: str):
    """Yerel depolamadan fotoğraf servis eder. S3 backend kullanıldığında bu endpoint atlanır."""
    if settings.STORAGE_BACKEND == "s3":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="S3 backend aktif — doğrudan S3/CDN URL'sini kullanın.",
        )
    filepath = _LOCAL_UPLOAD_DIR / filename
    if not filepath.exists() or not filepath.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fotoğraf bulunamadı")
    return FileResponse(filepath)
