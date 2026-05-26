"""APNs push bildirim gönderimi ve cihaz token yönetimi."""
import time
import logging
from typing import Optional
from redis.asyncio import Redis
import httpx
from jose import jwt

from app.core.config import settings

logger = logging.getLogger(__name__)

DEVICE_TOKEN_KEY = "user:apns_token:{user_id}"
APNS_HOST_PROD  = "https://api.push.apple.com"
APNS_HOST_DEV   = "https://api.sandbox.push.apple.com"


# --------------------------------------------------------------------------- #
# Device token kayıt / okuma
# --------------------------------------------------------------------------- #

async def save_device_token(redis: Redis, user_id: str, token: str) -> None:
    """Kullanıcının APNs cihaz token'ını Redis'e kaydeder."""
    key = DEVICE_TOKEN_KEY.format(user_id=user_id)
    await redis.set(key, token)


async def get_device_token(redis: Redis, user_id: str) -> Optional[str]:
    """Kullanıcının APNs cihaz token'ını Redis'ten okur."""
    key = DEVICE_TOKEN_KEY.format(user_id=user_id)
    value = await redis.get(key)
    if value is None:
        return None
    if isinstance(value, bytes):
        return value.decode()
    return value


# --------------------------------------------------------------------------- #
# APNs JWT token üretimi
# --------------------------------------------------------------------------- #

def _make_apns_jwt() -> str:
    """APNs için kısa ömürlü JWT üretir (.p8 private key ile)."""
    payload = {
        "iss": settings.APNS_TEAM_ID,
        "iat": int(time.time()),
    }
    return jwt.encode(
        payload,
        settings.APNS_PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": settings.APNS_KEY_ID},
    )


# --------------------------------------------------------------------------- #
# Push gönderme
# --------------------------------------------------------------------------- #

async def send_push(
    redis: Redis,
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Kullanıcıya APNs push bildirimi gönderir.
    Ayarlar eksikse (test ortamı) sessizce geçer.
    """
    if not settings.APNS_KEY_ID or not settings.APNS_TEAM_ID or not settings.APNS_PRIVATE_KEY:
        logger.debug("APNs ayarları eksik, bildirim gönderilmedi (user_id=%s)", user_id)
        return False

    device_token = await get_device_token(redis, user_id)
    if not device_token:
        return False

    host = APNS_HOST_PROD if settings.APNS_PRODUCTION else APNS_HOST_DEV
    url  = f"{host}/3/device/{device_token}"

    payload: dict = {
        "aps": {
            "alert": {"title": title, "body": body},
            "sound": "default",
            "badge": 1,
        }
    }
    if data:
        payload.update(data)

    headers = {
        "authorization": f"bearer {_make_apns_jwt()}",
        "apns-topic":    settings.APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority":  "10",
    }

    try:
        async with httpx.AsyncClient(http2=True, timeout=10) as client:
            resp = await client.post(url, json=payload, headers=headers)
        if resp.status_code == 200:
            return True
        logger.warning("APNs error %s for user %s: %s", resp.status_code, user_id, resp.text)
        return False
    except Exception as exc:
        logger.error("APNs send failed for user %s: %s", user_id, exc)
        return False


# --------------------------------------------------------------------------- #
# Yardımcı — bildirim tipine göre çağrılır
# --------------------------------------------------------------------------- #

async def notify_new_match(redis: Redis, user_id: str, other_name: str) -> None:
    """Eşleşme olduğunda karşı tarafa bildirim gönderir."""
    await send_push(
        redis,
        user_id,
        title="Yeni Eşleşme! 🎉",
        body=f"{other_name} ile eşleştin, sohbet başlat!",
        data={"type": "match"},
    )


async def notify_new_message(redis: Redis, user_id: str, sender_name: str) -> None:
    """Yeni mesaj geldiğinde alıcıya bildirim gönderir."""
    await send_push(
        redis,
        user_id,
        title=f"{sender_name}",
        body="Sana bir mesaj gönderdi.",
        data={"type": "message"},
    )
