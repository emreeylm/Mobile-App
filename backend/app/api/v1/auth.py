"""Auth endpoints: email/şifre + Apple/Google OAuth2 → JWT"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.db.session import get_db
from app.db.models import Kullanici
from app.schemas.auth import EmailLoginRequest, EmailRegisterRequest, RefreshRequest, SocialAuthRequest, TokenResponse
from app.services import auth_service
from app.services.password_service import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/check-email")
async def check_email(email: str, db: AsyncSession = Depends(get_db)):
    """Email adresinin kayıtlı olup olmadığını döner. Auth gerektirmez."""
    result = await db.execute(
        select(Kullanici).where(Kullanici.email == email.lower().strip())
    )
    exists = result.scalar_one_or_none() is not None
    return {"exists": exists}


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
                email=info["email"],
                auth_provider=body.provider,
                provider_id=info["sub"],
                isim=info.get("name") or info["email"].split("@")[0],
                yas=18,
                cinsiyet="belirtilmedi",
                hedef_cinsiyet="belirtilmedi",
                vip_bilet_bakiye=1,  # Hoşgeldin bileti
            )
            db.add(kullanici)
            await db.flush()

    user_id = str(kullanici.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=is_new,
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def email_register(
    body: EmailRegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Email + şifre ile yeni hesap oluşturur."""
    async with db.begin():
        existing = await db.execute(select(Kullanici).where(Kullanici.email == body.email))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu email zaten kayıtlı")

        kullanici = Kullanici(
            email=body.email,
            auth_provider="email",
            provider_id=f"email:{body.email}",
            isim=body.isim,
            yas=18,
            cinsiyet="belirtilmedi",
            hedef_cinsiyet="belirtilmedi",
            password_hash=hash_password(body.password),
            vip_bilet_bakiye=1,  # Hoşgeldin bileti
        )
        db.add(kullanici)
        await db.flush()

    user_id = str(kullanici.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=True,
    )


@router.post("/login", response_model=TokenResponse)
async def email_login(
    body: EmailLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Email + şifre ile giriş yapar."""
    result = await db.execute(select(Kullanici).where(Kullanici.email == body.email))
    kullanici = result.scalar_one_or_none()

    if not kullanici or not kullanici.password_hash:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bu e-postaya kayıtlı hesap bulunamadı")

    if not verify_password(body.password, kullanici.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="E-posta veya şifre hatalı")

    user_id = str(kullanici.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        is_new_user=False,
    )


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
