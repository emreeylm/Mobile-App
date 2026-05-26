"""TMDB API wrapper."""
import httpx
from app.core.config import settings


async def search_media(query: str, media_type: str = "multi") -> list[dict]:
    """Dizi veya film arar. media_type: 'multi' | 'movie' | 'tv'"""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{settings.TMDB_BASE_URL}/search/{media_type}",
            params={"api_key": settings.TMDB_API_KEY, "query": query, "language": "tr-TR"},
        )
    resp.raise_for_status()
    results = resp.json().get("results", [])
    return [
        {
            "id": r["id"],
            "baslik": r.get("title") or r.get("name", ""),
            "tip": r.get("media_type", media_type),
            "afis_url": f"https://image.tmdb.org/t/p/w500{r['poster_path']}" if r.get("poster_path") else None,
        }
        for r in results[:20]
    ]


async def get_popular(media_type: str = "movie") -> list[dict]:
    """Popüler dizi/filmleri getirir. media_type: 'movie' | 'tv'"""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{settings.TMDB_BASE_URL}/{media_type}/popular",
            params={"api_key": settings.TMDB_API_KEY, "language": "tr-TR"},
        )
    resp.raise_for_status()
    results = resp.json().get("results", [])
    return [
        {
            "id": r["id"],
            "baslik": r.get("title") or r.get("name", ""),
            "tip": media_type,
            "afis_url": f"https://image.tmdb.org/t/p/w500{r['poster_path']}" if r.get("poster_path") else None,
        }
        for r in results[:20]
    ]
