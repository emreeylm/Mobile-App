from pydantic import BaseModel, EmailStr


class SocialAuthRequest(BaseModel):
    provider: str  # 'apple' | 'google'
    id_token: str


class EmailRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    isim: str


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    is_new_user: bool


class RefreshRequest(BaseModel):
    refresh_token: str
