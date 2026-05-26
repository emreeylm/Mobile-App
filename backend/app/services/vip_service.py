"""Redis tabanlı VIP bilet yönetimi (race condition korumalı)."""
from redis.asyncio import Redis
from redis.exceptions import WatchError

VIP_KEY = "user:vip_tickets:{user_id}"
WELCOME_TICKET_COUNT = 1


async def get_balance(redis: Redis, user_id: str) -> int:
    val = await redis.get(VIP_KEY.format(user_id=user_id))
    return int(val) if val else 0


async def grant_welcome_ticket(redis: Redis, user_id: str) -> None:
    """Yeni kullanıcıya hoşgeldin bileti ver (yalnızca bir kez)."""
    key = VIP_KEY.format(user_id=user_id)
    await redis.setnx(key, WELCOME_TICKET_COUNT)


async def consume_vip_ticket(redis: Redis, user_id: str) -> bool:
    """Bilet tüketir. Race condition koruması için WATCH/MULTI/EXEC kullanır."""
    key = VIP_KEY.format(user_id=user_id)
    async with redis.pipeline(transaction=True) as pipe:
        while True:
            try:
                await pipe.watch(key)
                balance = int(await pipe.get(key) or 0)
                if balance <= 0:
                    return False
                pipe.multi()
                pipe.decr(key)
                await pipe.execute()
                return True
            except WatchError:
                continue


async def add_tickets(redis: Redis, user_id: str, count: int) -> int:
    """Satın alma sonrası bilet ekler. Yeni bakiye döner."""
    key = VIP_KEY.format(user_id=user_id)
    return await redis.incrby(key, count)
