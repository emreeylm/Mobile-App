from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    DATABASE_URL: str = "postgresql+asyncpg://user:pass@localhost:5432/bingedate"
    DATABASE_SSL: bool = False   # True → Supabase / üretim ortamı

    REDIS_URL: str = "redis://localhost:6379/0"

    JWT_SECRET: str = "change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    TMDB_API_KEY: str = ""
    TMDB_BASE_URL: str = "https://api.themoviedb.org/3"

    GOOGLE_CLIENT_ID: str = ""
    APPLE_TEAM_ID: str = ""
    APPLE_CLIENT_ID: str = ""

    # APNs push bildirimleri
    APNS_KEY_ID: str = ""
    APNS_TEAM_ID: str = ""
    APNS_PRIVATE_KEY: str = ""   # .p8 içeriği (satır sonu \n ile)
    APNS_BUNDLE_ID: str = ""
    APNS_PRODUCTION: bool = False

    # AdMob SSV
    ADMOB_SECRET_KEY: str = ""

    # Fotoğraf depolama: "local" (disk) veya "s3" (AWS S3 / Supabase Storage / R2)
    STORAGE_BACKEND: str = "local"
    S3_BUCKET: str = ""
    S3_REGION: str = "eu-west-1"
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    # Supabase Storage için: https://<project-ref>.supabase.co/storage/v1/s3
    # Boş bırakılırsa standart AWS S3 endpoint kullanılır
    S3_ENDPOINT_URL: str = ""
    # CDN / public URL prefix (boş bırakılırsa S3 URL kullanılır)
    S3_BASE_URL: str = ""

    # CORS — üretimde kısıtlayın: ["https://yourdomain.com"]
    ALLOWED_ORIGINS: list[str] = ["*"]

    @model_validator(mode="after")
    def _security_checks(self):
        if self.JWT_SECRET in ("change-me", "") or len(self.JWT_SECRET) < 32:
            import warnings
            warnings.warn(
                "⚠️  JWT_SECRET güvensiz veya çok kısa! Üretimde en az 32 karakterlik "
                "rastgele bir string kullanın.",
                stacklevel=2,
            )
        return self


settings = Settings()
