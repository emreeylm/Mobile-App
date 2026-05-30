"""Chat: WS /ws/chat/{other_user_id} + GET /chat/{other_user_id}/messages"""
import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis
from app.core.dependencies import get_current_user_id, get_db, get_redis
from app.db.models import Eslesme, ChatMesaj, Kullanici, Engelleme
from app.services import notification_service
from app.db.session import AsyncSessionLocal

router = APIRouter(tags=["chat"])

# Aktif WebSocket bağlantıları: oda_id → [(user_id_str, WebSocket)]
_connections: dict[str, list[tuple[str, WebSocket]]] = {}
_connections_lock = asyncio.Lock()


def _canonical_room(a: str, b: str) -> str:
    """İki kullanıcı ID'sinden tutarlı oda kimliği üretir."""
    lo, hi = sorted([a, b])
    return f"{lo}:{hi}"


async def _assert_matched(db: AsyncSession, user_id: uuid.UUID, other_id: uuid.UUID) -> None:
    """Karşılıklı eşleşme (like veya vip_bilet) yoksa veya engelleme varsa 403 fırlatır."""
    block_check = await db.execute(
        select(Engelleme).where(
            ((Engelleme.engelleyen_id == user_id) & (Engelleme.engellenen_id == other_id)) |
            ((Engelleme.engelleyen_id == other_id) & (Engelleme.engellenen_id == user_id))
        )
    )
    if block_check.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu kullanıcıyla sohbet edemezsiniz (engelleme mevcut)",
        )

    for g, a in [(user_id, other_id), (other_id, user_id)]:
        r = await db.execute(
            select(Eslesme).where(
                Eslesme.gonderen_id == g,
                Eslesme.alici_id == a,
                Eslesme.durum.in_(["like", "vip_bilet"]),
            )
        )
        if r.scalar_one_or_none() is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bu kullanıcıyla eşleşme bulunamadı",
            )


@router.websocket("/ws/chat/{other_user_id}")
async def chat_ws(
    other_user_id: uuid.UUID,
    websocket: WebSocket,
    redis: Redis = Depends(get_redis),
):
    """
    JWT access token'ı Sec-WebSocket-Protocol header'ında "bearer.<jwt>" formatında bekler.
    Geriye dönük uyumluluk için `token` query parametresi de kabul edilir.

    Mesaj formatı (gönderme): JSON {"text": "..."} veya düz metin.
    Mesaj formatı (alma):
      - {"type": "history", "id": int, "from": str, "text": str, "tarih": str}  — bağlanınca son 50
      - {"type": "message", "id": int, "from": str, "text": str, "tarih": str}  — yeni mesaj
    """
    from app.core.security import decode_token
    from jose import JWTError

    # Token: önce Sec-WebSocket-Protocol header'ı, yoksa query param (eski client uyumu)
    protocols = websocket.headers.get("sec-websocket-protocol", "")
    token = None
    selected_protocol = None
    for p in protocols.split(","):
        p = p.strip()
        if p.startswith("bearer."):
            token = p[len("bearer."):]
            selected_protocol = p
            break

    if not token:
        token = websocket.query_params.get("token")

    if not token:
        await websocket.close(code=4001)
        return

    # Token doğrulama
    try:
        payload = decode_token(token)
        user_id = uuid.UUID(payload["sub"])
    except (JWTError, KeyError, ValueError):
        await websocket.close(code=4001)
        return

    if user_id == other_user_id:
        await websocket.close(code=4000)
        return

    # Eşleşme doğrulama
    try:
        async with AsyncSessionLocal() as db:
            await _assert_matched(db, user_id, other_user_id)
    except HTTPException:
        await websocket.close(code=4003)
        return

    room = _canonical_room(str(user_id), str(other_user_id))
    await websocket.accept(subprotocol=selected_protocol)

    async with _connections_lock:
        _connections.setdefault(room, []).append((str(user_id), websocket))

    try:
        # Geçmiş mesajları gönder (son 50, kronolojik sıra)
        async with AsyncSessionLocal() as db:
            hist_result = await db.execute(
                select(ChatMesaj)
                .where(ChatMesaj.oda_id == room)
                .order_by(ChatMesaj.id.desc())
                .limit(50)
            )
            history_msgs = list(reversed(hist_result.scalars().all()))

        for msg in history_msgs:
            try:
                await websocket.send_json({
                    "type": "history",
                    "id": msg.id,
                    "from": str(msg.gonderen_id),
                    "text": msg.metin,
                    "tarih": msg.tarih.isoformat(),
                })
            except Exception:
                break

        while True:
            raw = await websocket.receive_text()

            # Metin ayrıştırma
            try:
                parsed = json.loads(raw)
                msg_type = parsed.get("type", "message")
                text = str(parsed.get("text", "")).strip()
            except (json.JSONDecodeError, AttributeError):
                msg_type = "message"
                text = raw.strip()

            # Typing indicator — DB'ye kaydetmeden diğer tarafa ilet
            if msg_type == "typing":
                async with _connections_lock:
                    current_conns = list(_connections.get(room, []))
                for uid, ws in current_conns:
                    if uid != str(user_id):
                        try:
                            await ws.send_json({"type": "typing", "from": str(user_id)})
                        except Exception:
                            pass
                continue

            if not text:
                continue

            # Mesajı DB'ye kaydet
            tarih_now = datetime.now(timezone.utc)
            new_msg = ChatMesaj(
                oda_id=room,
                gonderen_id=user_id,
                metin=text,
                tarih=tarih_now,
            )
            try:
                async with AsyncSessionLocal() as db:
                    db.add(new_msg)
                    await db.flush()
                    msg_id = new_msg.id
                    await db.commit()
            except Exception as exc:
                logger.error(f"Mesaj kaydedilemedi (oda={room}): {exc}")
                continue

            payload_out = {
                "type": "message",
                "id": msg_id,
                "from": str(user_id),
                "text": text,
                "tarih": tarih_now.isoformat(),
            }

            # Odadaki tüm bağlı istemcilere ilet
            async with _connections_lock:
                current_conns = list(_connections.get(room, []))

            dead: list[tuple[str, WebSocket]] = []
            other_is_online = False
            for uid, ws in current_conns:
                try:
                    await ws.send_json(payload_out)
                    if uid == str(other_user_id):
                        other_is_online = True
                except Exception:
                    dead.append((uid, ws))

            if dead:
                async with _connections_lock:
                    for item in dead:
                        try:
                            _connections[room].remove(item)
                        except ValueError:
                            pass

            # Karşı taraf çevrimdışıysa push bildirimi gönder
            if not other_is_online:
                async with AsyncSessionLocal() as db:
                    gonderen = await db.get(Kullanici, user_id)
                    gonderen_isim = gonderen.isim if gonderen else "Biri"
                await notification_service.notify_new_message(redis, str(other_user_id), gonderen_isim)

    except WebSocketDisconnect:
        pass
    finally:
        async with _connections_lock:
            conns = _connections.get(room, [])
            _connections[room] = [(uid, ws) for uid, ws in conns if ws is not websocket]
            if not _connections.get(room):
                _connections.pop(room, None)


@router.get("/chat/{other_user_id}/messages")
async def get_chat_history(
    other_user_id: uuid.UUID,
    limit: int = 50,
    before_id: int | None = None,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Sohbet geçmişini döner (kronolojik sıra, en yeni sonda).
    before_id ile cursor tabanlı sayfalama yapılabilir.
    """
    await _assert_matched(db, user_id, other_user_id)
    room = _canonical_room(str(user_id), str(other_user_id))

    q = select(ChatMesaj).where(ChatMesaj.oda_id == room)
    if before_id is not None:
        q = q.where(ChatMesaj.id < before_id)
    q = q.order_by(ChatMesaj.id.desc()).limit(min(limit, 100))

    result = await db.execute(q)
    msgs = list(reversed(result.scalars().all()))
    return {
        "messages": [
            {
                "id": m.id,
                "from": str(m.gonderen_id),
                "text": m.metin,
                "tarih": m.tarih.isoformat(),
            }
            for m in msgs
        ]
    }
