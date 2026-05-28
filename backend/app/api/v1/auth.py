"""Auth endpoints: Apple/Google OAuth2 → JWT"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.db.session import get_db
from app.db.models import Kullanici
from app.schemas.auth import (
    RefreshRequest, SocialAuthRequest, TokenResponse
)
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


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
