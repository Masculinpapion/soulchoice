#!/usr/bin/env python3
"""OSM geojsonseq → places CSV. stdout: CSV, stderr: özet istatistik.

Kolonlar: osm_ref,name,name_ru,name_en,category,lat,lng,street,housenumber,city_key
"""
import csv
import json
import sys

city = sys.argv[1]


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


w = csv.writer(sys.stdout)
stats = {}
addr_ok = 0
seen = set()

for line in sys.stdin:
    line = line.strip().lstrip("\x1e")  # geojsonseq RS ayracı
    if not line:
        continue
    try:
        f = json.loads(line)
    except json.JSONDecodeError:
        continue
    t = f.get("properties") or {}
    name = t.get("name") or t.get("name:en") or t.get("name:ru")
    if not name or len(name) > 120:
        continue
    cat = category(t)
    if cat is None:
        continue
    # Adsız park/anıt gürültüsünü ve dev alanları ele
    try:
        lat, lon = centroid(f["geometry"])
    except (KeyError, ZeroDivisionError, IndexError, TypeError):
        continue
    key = (name.lower(), round(lat, 3), round(lon, 3))
    if key in seen:  # node+bina kopyası
        continue
    seen.add(key)
    street = t.get("addr:street", "")
    if street:
        addr_ok += 1
    w.writerow([
        f.get("id", ""), name, t.get("name:ru", ""), t.get("name:en", ""),
        cat, f"{lat:.6f}", f"{lon:.6f}", street, t.get("addr:housenumber", ""), city,
    ])
    stats[cat] = stats.get(cat, 0) + 1

total = sum(stats.values())
pct = (100 * addr_ok // total) if total else 0
cats = ", ".join(f"{k}:{v}" for k, v in sorted(stats.items(), key=lambda x: -x[1]))
print(f"[özet] {city}: {total} kayıt, adres kapsamı %{pct} — {cats}", file=sys.stderr)
