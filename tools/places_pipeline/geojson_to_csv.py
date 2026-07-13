#!/usr/bin/env python3
"""OSM geojsonseq → places CSV. stdout: CSV, stderr: özet istatistik.

Kullanım: geojson_to_csv.py <city> <poi.geojsonseq> [addr.geojsonseq] [ctx.geojsonseq]
- addr: bina adres noktaları — adressiz POI'ye en yakın adres (≤50m) atanır
  (RU şehirlerinde adresler POI'de değil bina poligonlarında durur).
- ctx: metro istasyonları + semt merkezleri — "м. Тверская" / semt etiketi.

Kolonlar: osm_ref,name,name_ru,name_en,category,lat,lng,street,housenumber,
          metro,district,brand,website,city_key
"""
import csv
import json
import math
import sys

city = sys.argv[1]
poi_path = sys.argv[2]
addr_path = sys.argv[3] if len(sys.argv) > 3 else None
ctx_path = sys.argv[4] if len(sys.argv) > 4 else None

CELL = 0.0005  # ~50m grid hücresi (adres eşlemesi)


def features(path):
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip().lstrip("\x1e")  # geojsonseq RS ayracı
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def centroid(g):
    pts = []

    def flat(x):
        if isinstance(x[0], (int, float)):
            pts.append(x)
        else:
            for y in x:
                flat(y)

    flat(g["coordinates"])
    lon = sum(p[0] for p in pts) / len(pts)
    lat = sum(p[1] for p in pts) / len(pts)
    return lat, lon


def category(t):
    a = t.get("amenity")
    if a == "cafe":
        return "coffee"
    if a in ("restaurant", "fast_food", "food_court"):
        return "food"
    if a in ("bar", "pub", "nightclub", "biergarten"):
        return "bar"
    if a == "cinema":
        return "cinema"
    if a == "theatre":
        return "theater"
    if a == "arts_centre":
        return "culture"
    if a == "karaoke_box" or t.get("karaoke") == "yes":
        return "karaoke"
    if a in ("events_venue", "music_venue", "concert_hall"):
        return "concert"
    tour = t.get("tourism")
    if tour in ("museum", "gallery", "attraction", "zoo", "theme_park"):
        return "culture"
    if tour == "viewpoint":
        return "walk"
    l = t.get("leisure")
    if l in ("fitness_centre", "sports_centre", "stadium", "ice_rink", "bowling_alley"):
        return "sport"
    if l in ("park", "garden"):
        return "walk"
    if t.get("shop"):
        return "gift"
    return None


# --- Adres grid'i: bina adres noktaları ---
grid = {}
if addr_path:
    for f in features(addr_path):
        t = f.get("properties") or {}
        street, hnr = t.get("addr:street"), t.get("addr:housenumber")
        if not street or not hnr:
            continue
        try:
            lat, lon = centroid(f["geometry"])
        except (KeyError, ZeroDivisionError, IndexError, TypeError):
            continue
        key = (int(lat / CELL), int(lon / CELL))
        grid.setdefault(key, []).append((lat, lon, street, hnr))


def nearest_addr(lat, lon, max_m=50.0):
    ci, cj = int(lat / CELL), int(lon / CELL)
    best, best_d = None, max_m
    klon = 111320.0 * math.cos(math.radians(lat))
    for i in (ci - 1, ci, ci + 1):
        for j in (cj - 1, cj, cj + 1):
            for alat, alon, street, hnr in grid.get((i, j), ()):
                d = math.hypot((alat - lat) * 111320.0, (alon - lon) * klon)
                if d < best_d:
                    best, best_d = (street, hnr), d
    return best


# --- Bağlam: metro istasyonları + semtler ---
metros, suburbs = [], []
if ctx_path:
    seen_ctx = set()
    for f in features(ctx_path):
        t = f.get("properties") or {}
        nm = t.get("name")
        if not nm:
            continue
        try:
            lat, lon = centroid(f["geometry"])
        except (KeyError, ZeroDivisionError, IndexError, TypeError):
            continue
        is_metro = t.get("railway") == "station" and (
            t.get("station") in ("subway", "light_rail") or t.get("subway") == "yes"
        )
        is_suburb = t.get("place") in ("suburb", "neighbourhood", "quarter")
        key = (nm, is_metro, round(lat, 3), round(lon, 3))
        if key in seen_ctx:
            continue
        seen_ctx.add(key)
        if is_metro:
            metros.append((lat, lon, nm))
        elif is_suburb:
            suburbs.append((lat, lon, nm))


def nearest_ctx(items, lat, lon, max_m):
    best, best_d = "", max_m
    klon = 111320.0 * math.cos(math.radians(lat))
    for alat, alon, nm in items:
        dy = (alat - lat) * 111320.0
        if abs(dy) > best_d:
            continue
        d = math.hypot(dy, (alon - lon) * klon)
        if d < best_d:
            best, best_d = nm, d
    return best


# --- POI'ler ---
w = csv.writer(sys.stdout)
stats = {}
addr_ok = 0
addr_joined = 0
ctx_ok = 0
seen = set()

for f in features(poi_path):
    t = f.get("properties") or {}
    name = t.get("name") or t.get("name:en") or t.get("name:ru")
    if not name or len(name) > 120:
        continue
    cat = category(t)
    if cat is None:
        continue
    try:
        lat, lon = centroid(f["geometry"])
    except (KeyError, ZeroDivisionError, IndexError, TypeError):
        continue
    key = (name.lower(), round(lat, 3), round(lon, 3))
    if key in seen:  # node+bina kopyası
        continue
    seen.add(key)
    street, hnr = t.get("addr:street", ""), t.get("addr:housenumber", "")
    if not street and grid:
        hit = nearest_addr(lat, lon)
        if hit:
            street, hnr = hit
            addr_joined += 1
    if street:
        addr_ok += 1
    metro = nearest_ctx(metros, lat, lon, 1200.0) if metros else ""
    district = nearest_ctx(suburbs, lat, lon, 2500.0) if suburbs else ""
    if metro or district:
        ctx_ok += 1
    website = t.get("website") or t.get("contact:website") or ""
    w.writerow([
        f.get("id", ""), name, t.get("name:ru", ""), t.get("name:en", ""),
        cat, f"{lat:.6f}", f"{lon:.6f}", street, hnr,
        metro, district, t.get("brand", ""), website[:200], city,
    ])
    stats[cat] = stats.get(cat, 0) + 1

total = sum(stats.values())
pa = (100 * addr_ok // total) if total else 0
pc = (100 * ctx_ok // total) if total else 0
cats = ", ".join(f"{k}:{v}" for k, v in sorted(stats.items(), key=lambda x: -x[1]))
print(
    f"[özet] {city}: {total} kayıt, adres %{pa} (bina eşlemesi +{addr_joined}), "
    f"metro/semt %{pc}, istasyon:{len(metros)} semt:{len(suburbs)} — {cats}",
    file=sys.stderr,
)
