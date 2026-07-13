#!/usr/bin/env bash
# places yükleme — sunucuda çalışır. OSM CSV artifact'i + küratörlü tohumlar.
set -euo pipefail
cd /root/places_load

PSQL="docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1"

echo "== staging + yükleme =="
$PSQL <<'SQL'
begin;
create temp table stage_osm (
  osm_ref text, name text, name_ru text, name_en text, category text,
  lat float8, lng float8, street text, housenumber text,
  metro text, district text, brand text, website text, city_key text
) on commit drop;
\copy stage_osm from '/tmp/places_load/csv/places_moscow.csv' with (format csv)
\copy stage_osm from '/tmp/places_load/csv/places_spb.csv' with (format csv)
\copy stage_osm from '/tmp/places_load/csv/places_istanbul.csv' with (format csv)
\copy stage_osm from '/tmp/places_load/csv/places_dubai.csv' with (format csv)
\copy stage_osm from '/tmp/places_load/csv/places_london.csv' with (format csv)
\copy stage_osm from '/tmp/places_load/csv/places_berlin.csv' with (format csv)

insert into public.places (kind, name, name_ru, name_en, category, lat, lng,
  street, housenumber, metro, district, brand, website, city_key, source, osm_ref)
select 'venue', name, nullif(name_ru,''), nullif(name_en,''), category, lat, lng,
  nullif(street,''), nullif(housenumber,''), nullif(metro,''), nullif(district,''),
  nullif(brand,''), nullif(website,''), city_key, 'osm', osm_ref
from stage_osm
on conflict (osm_ref, city_key) where osm_ref is not null and osm_ref <> '' do nothing;

-- Küratörlü karaoke (name,street,housenumber,metro,lat,lng,city_key)
create temp table stage_kar (
  name text, street text, housenumber text, metro text,
  lat text, lng text, city_key text
) on commit drop;
\copy stage_kar from '/tmp/places_load/seeds/karaoke_moscow.csv' with (format csv)
\copy stage_kar from '/tmp/places_load/seeds/karaoke_spb.csv' with (format csv)
insert into public.places (kind, name, category, lat, lng, street, housenumber,
  metro, city_key, source)
select 'venue', name, 'karaoke', nullif(lat,'')::float8, nullif(lng,'')::float8,
  nullif(street,''), nullif(housenumber,''), nullif(metro,''), city_key, 'curated'
from stage_kar;

-- Markalar (market,name,name_en,website)
create temp table stage_brand (market text, name text, name_en text, website text)
on commit drop;
\copy stage_brand from '/tmp/places_load/seeds/brands.csv' with (format csv)
insert into public.places (kind, name, name_en, website, city_key, source)
select 'brand', name, nullif(name_en,''), website, market, 'curated' from stage_brand;

-- Destinasyonlar (name_ru,name_en,country_ru,country_en)
create temp table stage_dest (name_ru text, name_en text, country_ru text, country_en text)
on commit drop;
\copy stage_dest from '/tmp/places_load/seeds/destinations.csv' with (format csv)
insert into public.places (kind, name, name_en, country_ru, country_en, source)
select 'destination', name_ru, name_en, country_ru, country_en, 'curated' from stage_dest;

commit;
SQL

echo "== doğrulama =="
$PSQL -tc "select kind, source, count(*) from public.places group by 1,2 order by 1,2;"
$PSQL -tc "select city_key, count(*) from public.places where kind='venue' group by 1 order by 2 desc;"
