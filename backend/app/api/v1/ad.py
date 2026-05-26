"""POST /ad/reward + GET /ad/admob-ssv — Rewarded reklam"""
import uuid
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_redis
from app.services.swipe_service import grant_ad_bonus, AD_BONUS
from app.services.ad_service import verify_admob_ssv

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ad", tags=["ad"])


@router.post("/reward")
async def claim_ad_reward(
    user_id: uuid.UUID = Depends(get_current_user_id),
    redis: Redis = Depends(get_redis),
):
    """
    Kullanıcı rewarded reklam izledikten sonra bu endpoint'i çağırır.
    Günlük swipe kotasına AD_BONUS kadar ek hak verir.
    NOT: Güvenli ortamda bu endpoint yerine AdMob SSV callback'ini (GET /ad/admob-ssv) kullan.
    """
    new_remaining = await grant_ad_bonus(redis, str(user_id))
    return {"basarili": True, "kalan_hak": new_remaining, "bonus_eklendi": AD_BONUS}


@router.get("/admob-ssv")
async def admob_ssv_callback(
    request: Request,
    redis: Redis = Depends(get_redis),
):
    """
    AdMob Server-Side Verification callback endpoint'i.
    AdMob bu URL'yi kullanıcı reklam izledikten sonra GET ile çağırır.
    İmza ECDSA-SHA256 ile Google public key'leri kullanılarak doğrulanır.
    Query parametreleri: ad_network, ad_unit_id, custom_data (user_id), reward_amount,
                        reward_item, timestamp, transaction_id, user_id, signature, key_id
    """
    params = dict(request.query_params)

    if not await verify_admob_ssv(params):
        logger.warning("AdMob SSV imza doğrulama başarısız: %s", {k: v for k, v in params.items() if k != "signature"})
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Geçersiz SSV imzası")

    raw_user_id = params.get("custom_data") or params.get("user_id")
    if not raw_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="user_id eksik")

    try:
        user_id = uuid.UUID(raw_user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Geçersiz user_id")

    await grant_ad_bonus(redis, str(user_id))
    logger.info("AdMob SSV reward granted for user %s", user_id)
    return {"ok": True}
