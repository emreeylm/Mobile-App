from pydantic import BaseModel, EmailStr


class SocialAuthRequest(BaseModel):
    provider: str  # 'apple' | 'google'
    id_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    is_new_user: bool


# MARK: - Telefon OTP Auth

class PhoneOTPRequest(BaseModel):
    telefon: str   # E.164: +905xxxxxxxxx


class PhoneOTPResponse(BaseModel):
    sent: bool
    # Demo modda OTP kodu döner (production'da None)
    otp_code: str | None = None


class PhoneVerifyRequest(BaseModel):
    telefon: str
    otp_code: str
