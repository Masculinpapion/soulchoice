#!/usr/bin/env bash
# OSM → places CSV pipeline. Geçici runner'da çalışır, prod'a dokunmaz.
# Kullanım: build_places.sh "moscow,spb"
set -euo pipefail

CITIES="${1:-moscow,spb}"
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p out src

declare -A SRC BBOX
SRC[moscow]="https://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf"
BBOX[moscow]="37.30,55.55,37.90,55.95"
SRC[spb]="https://download.geofabrik.de/russia/northwestern-fed-district-latest.osm.pbf"
BBOX[spb]="30.05,59.75,30.60,60.10"
SRC[istanbul]="https://download.geofabrik.de/europe/turkey-latest.osm.pbf"
BBOX[istanbul]="28.60,40.80,29.40,41.25"
SRC[dubai]="https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf"
BBOX[dubai]="54.90,24.90,55.65,25.40"
SRC[london]="https://download.geofabrik.de/europe/united-kingdom/england/greater-london-latest.osm.pbf"
BBOX[london]="-0.55,51.25,0.35,51.72"
SRC[berlin]="https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf"
BBOX[berlin]="13.05,52.30,13.80,52.70"

# 12 uygulama kategorisine eşlenen OSM tag'leri (eşleme geojson_to_csv.py'de)
FILTERS=(
  "nwr/amenity=restaurant,cafe,fast_food,food_court,bar,pub,nightclub,biergarten,cinema,theatre,arts_centre,karaoke_box,events_venue,music_venue,concert_hall"
  "nwr/leisure=fitness_centre,sports_centre,stadium,ice_rink,bowling_alley"
  "nwr/leisure=park,garden"
  "nwr/tourism=museum,gallery,attraction,zoo,theme_park,viewpoint"
  "nwr/shop=mall,department_store,cosmetics,perfumery,jewelry,gift,books,florist,chocolate,confectionery,toys"
)

for c in ${CITIES//,/ }; do
  [ -n "${SRC[$c]:-}" ] || { echo "bilinmeyen şehir: $c" >&2; exit 1; }
  f="src/$(basename "${SRC[$c]}")"
  if [ ! -f "$f" ]; then
    echo "== $c: kaynak indiriliyor: ${SRC[$c]}"
    curl -sSL --retry 3 -o "$f" "${SRC[$c]}"
  fi
  echo "== $c: bbox extract"
  osmium extract -b "${BBOX[$c]}" "$f" -o "tmp_$c.pbf" --overwrite
  echo "== $c: tag filtresi"
  osmium tags-filter "tmp_$c.pbf" "${FILTERS[@]}" -o "poi_$c.pbf" --overwrite
  echo "== $c: bina adresleri (POI'lere en yakın adres eşlemesi için)"
  osmium tags-filter "tmp_$c.pbf" nwr/addr:housenumber -o "addr_$c.pbf" --overwrite
  osmium export "addr_$c.pbf" -f geojsonseq -o "addr_$c.geojsonseq" --overwrite
  echo "== $c: export + CSV"
  osmium export "poi_$c.pbf" -f geojsonseq --add-unique-id=type_id -o "poi_$c.geojsonseq" --overwrite
  python3 "$DIR/geojson_to_csv.py" "$c" "poi_$c.geojsonseq" "addr_$c.geojsonseq" > "out/places_$c.csv"
  rm -f "tmp_$c.pbf" "poi_$c.pbf" "poi_$c.geojsonseq" "addr_$c.pbf" "addr_$c.geojsonseq"
done

echo ""
echo "== KALİTE PROBLARI (bilinen mekânlar CSV'de var mı) =="
for p in "White Rabbit" "Кофемания" "Большой театр" "DUO" "Мариинский" "Mikla" "Ravi" "Zuma" "Кинотеатр"; do
  m=$(grep -h -m1 -i -- "$p" out/*.csv 2>/dev/null || true)
  if [ -n "$m" ]; then echo "✓ $p → ${m:0:140}"; else echo "✗ $p bulunamadı"; fi
done
echo ""
echo "== ÇIKTILAR =="
wc -l out/*.csv
