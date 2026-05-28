"""Eşleşme algoritması: PostGIS + ortak medya skoru."""
import uuid
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def get_discover_feed(
    db: AsyncSession,
    user_id: uuid.UUID,
    user_lat: float,
    user_lon: float,
    user_yas: int,
    istenen_cinsiyet: str,
    is_premium: bool,
    global_mod: bool = False,
    min_age_override: int | None = None,
    max_age_override: int | None = None,
    max_distance_km_override: int | None = None,
    min_boy_override: int | None = None,
    max_boy_override: int | None = None,
) -> list[dict]:
    """
    Uyumlu kullanıcıları ortak medya sayısına göre sıralar.
    Ücretsiz: gizli ±5 yaş ve 100 km sınırı uygulanır.
    Premium: yaş/mesafe parametrik (override desteklenir). Global mod: mesafe sınırı yok.
    """
    if is_premium:
        yas_min = min_age_override if min_age_override is not None else user_yas - 20
        yas_max = max_age_override if max_age_override is not None else user_yas + 20
        if global_mod:
            mesafe_limit = None
        elif max_distance_km_override is not None:
            mesafe_limit = max_distance_km_override * 1000
        else:
            mesafe_limit = 500_000
    else:
        yas_min, yas_max = user_yas - 5, user_yas + 5
        mesafe_limit = 100_000

    mesafe_filtre = (
        ""
        if mesafe_limit is None
        else "AND ST_DistanceSphere(hedef.konum, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)) <= :mesafe_limit"
    )

    # Boy filtresi (premium): boy_gizli=True olan kullanıcılar da dahil, sadece boy değeri aralıkta olanlar
    boy_filtre = ""
    if min_boy_override is not None or max_boy_override is not None:
        boy_filtre = "AND hedef.boy IS NOT NULL"
        if min_boy_override is not None:
            boy_filtre += " AND hedef.boy >= :min_boy"
        if max_boy_override is not None:
            boy_filtre += " AND hedef.boy <= :max_boy"

    # Engellenen / engelleyen kullanıcıları her iki yönde filtrele
    engel_filtre = """
          AND hedef.id::text NOT IN (
              SELECT engellenen_id::text FROM tbl_engellemeler WHERE engelleyen_id = :user_id
              UNION
              SELECT engelleyen_id::text FROM tbl_engellemeler WHERE engellenen_id = :user_id
          )
    """

    sql = text(f"""
        SELECT
            hedef.id,
            hedef.isim,
            hedef.yas,
            hedef.now_watching,
            hedef.boy,
            hedef.boy_gizli,
            COUNT(ortak.medya_id) AS uyumluluk_skoru,
            (
                SELECT m2.afis_url
                FROM tbl_kullanici_medya km2
                JOIN tbl_medya m2 ON km2.medya_id = m2.id
                WHERE km2.kullanici_id = hedef.id
                  AND m2.afis_url IS NOT NULL
                LIMIT 1
            ) AS foto_url,
            (
                SELECT STRING_AGG(m3.baslik, ', ' ORDER BY m3.baslik)
                FROM (
                    SELECT m3i.baslik
                    FROM tbl_kullanici_medya km3
                    JOIN tbl_medya m3i ON km3.medya_id = m3i.id
                    WHERE km3.kullanici_id = hedef.id
                      AND km3.medya_id IN (
                          SELECT medya_id FROM tbl_kullanici_medya WHERE kullanici_id = :user_id
                      )
                    LIMIT 3
                ) m3(baslik)
            ) AS ortak_medya_list
        FROM tbl_kullanicilar hedef
        JOIN tbl_kullanici_medya ortak ON hedef.id = ortak.kullanici_id
        WHERE hedef.cinsiyet = :istenen_cinsiyet
          AND hedef.yas BETWEEN :yas_min AND :yas_max
          AND hedef.id != :user_id
          AND hedef.konum IS NOT NULL
          {mesafe_filtre}
          {boy_filtre}
          {engel_filtre}
          AND hedef.id::text NOT IN (
              SELECT alici_id::text FROM tbl_eslesmeler WHERE gonderen_id = :user_id
          )
          AND ortak.medya_id IN (
              SELECT medya_id FROM tbl_kullanici_medya WHERE kullanici_id = :user_id
          )
        GROUP BY hedef.id, hedef.isim, hedef.yas, hedef.now_watching, hedef.boy, hedef.boy_gizli
        ORDER BY uyumluluk_skoru DESC
        LIMIT 50
    """)

    params = {
        "istenen_cinsiyet": istenen_cinsiyet,
        "yas_min": yas_min,
        "yas_max": yas_max,
        "user_id": str(user_id),
        "lat": user_lat,
        "lon": user_lon,
    }
    if mesafe_limit is not None:
        params["mesafe_limit"] = mesafe_limit
    if min_boy_override is not None:
        params["min_boy"] = min_boy_override
    if max_boy_override is not None:
        params["max_boy"] = max_boy_override

    result = await db.execute(sql, params)
    rows = result.mappings().all()
    out = []
    for r in rows:
        d = dict(r)
        # ortak_medya_list → liste dönüşümü
        raw_list = d.pop("ortak_medya_list", None)
        d["ortak_medya"] = [s.strip() for s in raw_list.split(",")] if raw_list else []
        # boy_gizli=True ise boy'u gizle (filtreleme çalışır ama kart'ta gösterilmez)
        boy_gizli = d.pop("boy_gizli", False)
        if boy_gizli:
            d["boy"] = None
        out.append(d)
    return out
