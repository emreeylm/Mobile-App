"""Apple ve Google id_token doğrulaması."""
import httpx
from jose import jwt as jose_jwt
from app.core.config import settings


async def verify_google_token(id_token: str) -> dict:
    """Google id_token'ı doğrular; {'sub': ..., 'email': ..., 'name': ...} döner."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
        )
    if resp.status_code != 200:
        raise ValueError("Invalid Google token")
    data = resp.json()
    if data.get("aud") != settings.GOOGLE_CLIENT_ID:
        raise ValueError("Google token audience mismatch")
    return {"sub": data["sub"], "email": data["email"], "name": data.get("name", "")}


async def verify_apple_token(id_token: str) -> dict:
    """Apple id_token'ı Apple public key'lerle doğrular."""
    async with httpx.AsyncClient() as client:
        resp = await client.get("https://appleid.apple.com/auth/keys")
    keys = resp.json()["keys"]

    header = jose_jwt.get_unverified_header(id_token)
    matching_key = next((k for k in keys if k["kid"] == header["kid"]), None)
    if not matching_key:
        raise ValueError("Apple key not found")

    payload = jose_jwt.decode(
        id_token,
        matching_key,
        algorithms=["RS256"],
        audience=settings.APPLE_CLIENT_ID,
    )
    return {"sub": payload["sub"], "email": payload.get("email", ""), "name": ""}
