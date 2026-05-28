from pydantic import BaseModel


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
