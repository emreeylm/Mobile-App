"""Rewarded ad callback doğrulaması (AdMob SSV — ECDSA/SHA-256)."""
import base64
import logging
import time
from urllib.parse import urlencode

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

logger = logging.getLogger(__name__)

_ADMOB_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json"
_KEY_CACHE_TTL = 3600  # saniye

_key_cache: dict[int, ec.EllipticCurvePublicKey] = {}
_key_cache_loaded_at: float = 0.0


async def _fetch_admob_keys() -> None:
    """Google'ın SSV public key'lerini indirir ve cache'e yazar."""
    global _key_cache, _key_cache_loaded_at
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(_ADMOB_KEYS_URL)
        resp.raise_for_status()
    data = resp.json()
    new_cache: dict[int, ec.EllipticCurvePublicKey] = {}
    for entry in data.get("keys", []):
        key_id: int = int(entry["keyId"])
        pem: str = entry["pem"]
        key = serialization.load_pem_public_key(pem.encode())
        if isinstance(key, ec.EllipticCurvePublicKey):
            new_cache[key_id] = key
    _key_cache = new_cache
    _key_cache_loaded_at = time.monotonic()
    logger.info("AdMob SSV public keys loaded: %d key(s)", len(_key_cache))


async def _get_public_key(key_id: int) -> ec.EllipticCurvePublicKey | None:
    """Cache'den key döner; süresi dolmuşsa yeniler."""
    if time.monotonic() - _key_cache_loaded_at > _KEY_CACHE_TTL or not _key_cache:
        await _fetch_admob_keys()
    return _key_cache.get(key_id)


def build_admob_verify_string(params: dict) -> str:
    """
    AdMob SSV doğrulama için imzalanan query string.
    'signature' ve 'key_id' parametreleri hariç, kalan anahtarlar alfabetik sırada birleştirilir.
    """
    filtered = {k: v for k, v in sorted(params.items()) if k not in ("signature", "key_id")}
    return urlencode(filtered)


async def verify_admob_ssv(params: dict) -> bool:
    """
    AdMob SSV callback'ini ECDSA-SHA256 ile doğrular.
    Başarılıysa True, aksi halde False döner.
    """
    try:
        key_id = int(params.get("key_id", 0))
        raw_sig = params.get("signature", "")
    except (ValueError, TypeError):
        logger.warning("AdMob SSV: geçersiz key_id veya signature parametresi")
        return False

    public_key = await _get_public_key(key_id)
    if public_key is None:
        logger.warning("AdMob SSV: key_id=%d bulunamadı", key_id)
        return False

    verify_str = build_admob_verify_string(params)

    # Signature base64url-encoded; padding eksik olabilir
    try:
        padding = (4 - len(raw_sig) % 4) % 4
        sig_bytes = base64.urlsafe_b64decode(raw_sig + "=" * padding)
    except Exception:
        logger.warning("AdMob SSV: signature base64 decode hatası")
        return False

    try:
        public_key.verify(sig_bytes, verify_str.encode(), ec.ECDSA(hashes.SHA256()))
        return True
    except InvalidSignature:
        logger.warning("AdMob SSV: imza geçersiz (key_id=%d)", key_id)
        return False
    except Exception as exc:
        logger.error("AdMob SSV: beklenmeyen doğrulama hatası: %s", exc)
        return False
