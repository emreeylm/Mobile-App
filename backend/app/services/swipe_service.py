"""Redis tabanlı günlük swipe kota yönetimi."""
from datetime import datetime, timezone, timedelta
import math
from redis.asyncio import Redis
from redis.exceptions import WatchError

SWIPE_KEY = "user:swipes:count:{user_id}"
DAILY_LIMIT = 10
AD_BONUS = 5


def _next_midnight_ts() -> int:
    now = datetime.now(timezone.utc)
    tomorrow = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if tomorrow <= now:
        tomorrow = tomorrow + timedelta(days=1)
    return math.floor(tomorrow.timestamp())


async def check_and_increment_swipe(redis: Redis, user_id: str) -> tuple[bool, int]:
    """Swipe hakkı varsa artırır. (izin_var, kalan_hak) döner."""
    key = SWIPE_KEY.format(user_id=user_id)
    async with redis.pipeline(transaction=True) as pipe:
        while True:
            try:
                await pipe.watch(key)
                current = await pipe.get(key)
                current_count = int(current) if current else 0
                if current_count >= DAILY_LIMIT:
                    return False, 0
                pipe.multi()
                pipe.incr(key)
                pipe.expireat(key, _next_midnight_ts())
                await pipe.execute()
                return True, DAILY_LIMIT - current_count - 1
            except WatchError:
                continue


async def grant_ad_bonus(redis: Redis, user_id: str) -> int:
    """Reklam izleme bonusu ekler. Yeni toplam döner."""
    key = SWIPE_KEY.format(user_id=user_id)
    current = await redis.get(key)
    current_count = int(current) if current else 0
    new_count = max(0, current_count - AD_BONUS)
    await redis.set(key, new_count)
    await redis.expireat(key, _next_midnight_ts())
    return DAILY_LIMIT - new_count


async def get_remaining(redis: Redis, user_id: str) -> int:
    """Kota artırmadan mevcut kalan beğeni hakkını döner."""
    key = SWIPE_KEY.format(user_id=user_id)
    current = await redis.get(key)
    current_count = int(current) if current else 0
    return max(0, DAILY_LIMIT - current_count)


async def decrement_swipe(redis: Redis, user_id: str) -> None:
    """Rewind sonrası swipe sayacını 1 azaltır. Sıfırın altına düşmez."""
    key = SWIPE_KEY.format(user_id=user_id)
    current = await redis.get(key)
    if current and int(current) > 0:
        await redis.decr(key)

