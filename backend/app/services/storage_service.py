"""
Fotoğraf depolama soyutlama katmanı.

STORAGE_BACKEND=local  → sunucu diskine yazar, /api/v1/users/photos/{filename} URL döner
STORAGE_BACKEND=s3     → AWS S3 (veya Cloudflare R2) bucket'ına yazar, public URL döner

Kullanım:
    url = await upload_file(data=bytes_data, filename="user_abc.jpg", content_type="image/jpeg")
"""
import hashlib
import logging
import os
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)

# Yerel disk dizini (STORAGE_BACKEND=local için)
_LOCAL_UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/tmp/bingedate_photos"))
_LOCAL_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


async def upload_file(data: bytes, filename: str, content_type: str) -> str:
    """
    Dosyayı yapılandırılmış backend'e yükler ve erişim URL'si döner.

    Args:
        data:         Ham bayt dizisi (fotoğraf içeriği)
        filename:     Hedef dosya adı, ör. "uuid_abc123.jpg"
        content_type: MIME türü, ör. "image/jpeg"

    Returns:
        Erişilebilir public URL string
    """
    if settings.STORAGE_BACKEND == "s3":
        return await _upload_s3(data, filename, content_type)
    return _upload_local(data, filename)


def _upload_local(data: bytes, filename: str) -> str:
    """Dosyayı yerel diske yazar. Üretim için S3 kullanın."""
    filepath = _LOCAL_UPLOAD_DIR / filename
    filepath.write_bytes(data)
    logger.debug("Local upload: %s (%d bytes)", filename, len(data))
    return f"/api/v1/users/photos/{filename}"


async def _upload_s3(data: bytes, filename: str, content_type: str) -> str:
    """
    Dosyayı S3 bucket'ına yükler ve public URL döner.

    Gerekli env değişkenleri:
        S3_BUCKET, S3_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    Opsiyonel:
        S3_BASE_URL — CDN prefix (boş bırakılırsa doğrudan S3 URL kullanılır)
    """
    try:
        import aioboto3  # type: ignore[import]
    except ImportError:
        logger.warning("aioboto3 yüklü değil, local storage'a düşülüyor. `pip install aioboto3` çalıştırın.")
        return _upload_local(data, filename)

    if not settings.S3_BUCKET:
        logger.warning("S3_BUCKET tanımlanmamış, local storage'a düşülüyor.")
        return _upload_local(data, filename)

    session = aioboto3.Session(
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.S3_REGION,
    )

    # Supabase Storage veya Cloudflare R2 gibi S3-uyumlu servisler
    # için endpoint_url gereklidir. AWS S3 için boş bırakılır.
    client_kwargs: dict = {}
    if settings.S3_ENDPOINT_URL:
        client_kwargs["endpoint_url"] = settings.S3_ENDPOINT_URL

    async with session.client("s3", **client_kwargs) as s3:
        put_kwargs: dict = dict(
            Bucket=settings.S3_BUCKET,
            Key=f"photos/{filename}",
            Body=data,
            ContentType=content_type,
        )
        # Supabase Storage ACL desteklemez; standart S3 için public-read
        if not settings.S3_ENDPOINT_URL:
            put_kwargs["ACL"] = "public-read"

        await s3.put_object(**put_kwargs)
        logger.info("S3 upload: %s → %s (%d bytes)", filename, settings.S3_BUCKET, len(data))

    if settings.S3_BASE_URL:
        return f"{settings.S3_BASE_URL.rstrip('/')}/photos/{filename}"
    return f"https://{settings.S3_BUCKET}.s3.{settings.S3_REGION}.amazonaws.com/photos/{filename}"


def make_filename(user_id: str, data: bytes, content_type: str) -> str:
    """
    Kullanıcı ID + veri hash kombinasyonundan tekrarlanmaz dosya adı üretir.
    Aynı fotoğraf tekrar yüklenirse aynı adı döner (idempotent).
    """
    ext = content_type.split("/")[-1].replace("jpeg", "jpg")
    photo_id = hashlib.sha256(f"{user_id}-{data[:64]}".encode()).hexdigest()[:16]
    return f"{user_id}_{photo_id}.{ext}"
