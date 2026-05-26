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
        raise ValueError(f"Invalid Google token: {resp.text}")
    data = resp.json()

    # iOS GIDSignIn token'larında aud veya azp alanlarından biri client_id'ye eşit olmalı.
    # GOOGLE_CLIENT_ID boşsa audience kontrolünü atla (geliştirme kolaylığı).
    client_id = settings.GOOGLE_CLIENT_ID
    if client_id:
        token_aud = data.get("aud", "")
        token_azp = data.get("azp", "")
        if client_id not in (token_aud, token_azp):
            raise ValueError(
                f"Google token audience mismatch. "
                f"expected={client_id} aud={token_aud} azp={token_azp}"
            )

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
