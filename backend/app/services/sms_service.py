"""NetGSM üzerinden SMS OTP gönderimi (Türkiye).

Demo modda (OTP_DEMO_MODE=true) gerçek SMS gönderilmez; OTP kodu response'da döner.
Production'da OTP_DEMO_MODE=false ve NetGSM credentials dolu olmalıdır.
"""
import secrets
import httpx
from app.core.config import settings


def generate_otp() -> str:
    """6 haneli kriptografik olarak güvenli OTP üretir."""
    return str(secrets.randbelow(900000) + 100000)


async def send_otp_sms(telefon: str, otp: str) -> bool:
    """
    NetGSM API üzerinden OTP SMS gönderir.
    telefon: E.164 formatında (+905xxxxxxxxx)
    True → başarıyla gönderildi | False → hata
    """
    if settings.OTP_DEMO_MODE:
        # Demo modda gerçek SMS gönderilmez
        return True

    if not settings.NETGSM_USERCODE or not settings.NETGSM_PASSWORD:
        return False

    params = {
        "usercode": settings.NETGSM_USERCODE,
        "password": settings.NETGSM_PASSWORD,
        "gsmno": telefon,
        "text": f"Binge dogrulama kodunuz: {otp}. 2 dakika gecerlidir.",
        "msgheader": settings.NETGSM_MSGHEADER,
    }
    try:
        async with httpx.AsyncClient() as client:
            r = await client.get(
                "https://api.netgsm.com.tr/sms/send/get/",
                params=params,
                timeout=10,
            )
        # NetGSM başarı yanıtı "00 XXXXXX" ile başlar
        return r.text.strip().startswith("00")
    except Exception:
        return False
