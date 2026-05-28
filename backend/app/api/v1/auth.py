"""Auth endpoints: Telefon OTP + Apple/Google OAuth2 → JWT"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.dependencies import get_redis
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.db.session import get_db
from app.db.models import Kullanici
from app.schemas.auth import (
    PhoneOTPRequest, PhoneOTPResponse, PhoneVerifyRequest,
    RefreshRequest, SocialAuthRequest, TokenResponse
)
from app.services import auth_service
from app.services.sms_service import generate_otp, send_otp_sms

router = APIRouter(prefix="/auth", tags=["auth"])

_OTP_TTL = 120           # 2 dakika (saniye)
_OTP_RATELIMIT_TTL = 60  # 1/dakika rate limit
_OTP_DAILY_MAX = 5       # günlük max SMS


# MARK: - Telefon OTP

@router.post("/phone/request-otp", response_model=PhoneOTPResponse)
async def request_phone_otp(
    body: PhoneOTPRequest,
    redis: Redis = Depends(get_redis),
):
    """
    Telefon numarasına 6 haneli OTP gönderir.
    Rate limit: aynı numaraya 1/dk, günde max 5 SMS.
    Demo modda SMS gönderilmez, OTP kodu response'da döner.
    """
    telefon = body.telefon.strip()

    # Rate limit: 1/dakika
    rl_key = f"otp:ratelimit:{telefon}"
    if await redis.exists(rl_key):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Çok sık istek. 1 dakika bekleyip tekrar deneyin.",
        )
    await redis.setex(rl_key, _OTP_RATELIMIT_TTL, "1")

    # Rate limit: günlük max
    daily_key = f"otp:daily:{telefon}"
    daily_count = await redis.get(daily_key)
    if daily_count and int(daily_count) >= _OTP_DAILY_MAX:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Günlük SMS limitine ulaşıldı. Yarın tekrar deneyin.",
        )
    pipe = redis.pipeline()
    pipe.incr(daily_key)
    pipe.expire(daily_key, 86400)  # 24 saat TTL
    await pipe.execute()

    # OTP üret ve kaydet
    otp = generate_otp()
    await redis.setex(f"otp:{telefon}", _OTP_TTL, otp)

    # SMS gönder (demo modda atlanır)
    await send_otp_sms(telefon, otp)

    return PhoneOTPResponse(
        sent=True,
        otp_code=otp if settings.OTP_DEMO_MODE else None,
    )


@router.post("/phone/verify-otp", response_model=TokenResponse)
async def verify_phone_otp(
    body: PhoneVerifyRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """
    OTP doğrular. Kullanıcı yoksa oluşturur (yeni kayıt), varsa giriş yapar.
    is_new_user=true → iOS onboarding akışına yönlendirir.
    """
    telefon = body.telefon.strip()
    stored_otp = await redis.get(f"otp:{telefon}")

    if not stored_otp or stored_otp != body.otp_code.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz veya süresi dolmuş doğrulama kodu.",
        )

    # Tek kullanımlık — hemen sil
    await redis.delete(f"otp:{telefon}")

    async with db.begin():
        result = await db.execute(
            select(Kullanici).where(Kullanici.telefon == telefon)
        )
        kullanici = result.scalar_one_or_none()
        is_new = kullanici is None

        if is_new:
            kullanici = Kullanici(
                telefon=telefon,
                auth_provider="phone",
                provider_id=f"phone:{telefon}",
                isim="Kullanıcı",          # onboarding'de PATCH /users/me ile güncellenir
                yas=18,
                cinsiyet="belirtilmedi",
                hedef_cinsiyet="belirtilmedi",
                vip_bilet_bakiye=1,        # hoşgeldin bileti
            )
            db.add(kullanici)
            await db.flush()

    user_id = str(kullanici.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=is_new,
    )


# MARK: - Social (Apple / Google)

@router.post("/social", response_model=TokenResponse)
async def social_login(
    body: SocialAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """Apple veya Google id_token'ı doğrular; kullanıcı yoksa oluşturur."""
    try:
        if body.provider == "google":
            info = await auth_service.verify_google_token(body.id_token)
        elif body.provider == "apple":
            info = await auth_service.verify_apple_token(body.id_token)
        else:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported provider")
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    async with db.begin():
        result = await db.execute(
            select(Kullanici).where(
                Kullanici.provider_id == info["sub"],
                Kullanici.auth_provider == body.provider,
            )
        )
        kullanici = result.scalar_one_or_none()
        is_new = kullanici is None

        if is_new:
            kullanici = Kullanici(
                email=info.get("email"),
                auth_provider=body.provider,
                provider_id=info["sub"],
                isim=info.get("name") or (info.get("email") or "Kullanıcı").split("@")[0],
                yas=18,
                cinsiyet="belirtilmedi",
                hedef_cinsiyet="belirtilmedi",
                vip_bilet_bakiye=1,
            )
            db.add(kullanici)
            await db.flush()

    user_id = str(kullanici.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=is_new,
    )


# MARK: - Token Refresh

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(body: RefreshRequest):
    """Refresh token ile yeni access token üretir."""
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")
        user_id = payload["sub"]
    except (JWTError, KeyError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=False,
    )
