-- Yer seçimi: 12 kategori tek çatı (14.07.2026, onaylı tasarım)
-- YALNIZ YENİ NESNELER — mevcut tablolara dokunulmaz.
begin;

create extension if not exists pg_trgm;
create extension if not exists unaccent;

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('venue','destination','brand')),
  name text not null,
  name_ru text,
  name_en text,
  category text,
  lat double precision,
  lng double precision,
  street text,
  housenumber text,
  metro text,
  district text,
  brand text,
  website text,
  country_ru text,
  country_en text,
  city_key text,
  source text not null default 'osm' check (source in ('osm','curated','user')),
  osm_ref text,
  usage_count integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists places_name_trgm
  on public.places using gin (lower(name) gin_trgm_ops);
create index if not exists places_name_en_trgm
  on public.places using gin (lower(coalesce(name_en,'')) gin_trgm_ops);
create index if not exists places_city_kind on public.places (city_key, kind);
create unique index if not exists places_osm_ref_uq
  on public.places (osm_ref, city_key) where osm_ref is not null and osm_ref <> '';

-- cities.id (UUID) <-> pipeline city_key eşlemesi + şehir merkezi + marka pazarı
create table if not exists public.city_keys (
  city_id uuid primary key references public.cities(id),
  key text not null unique,
  brand_market text not null,
  center_lat double precision not null,
  center_lng double precision not null
);

insert into public.city_keys (city_id, key, brand_market, center_lat, center_lng) values
  ('3f08d6f3-c1c1-4315-996f-4b5232441b44','moscow','ru',55.7539,37.6208),
  ('407e864c-f039-44d8-86ef-c2606fb07c43','spb','ru',59.9343,30.3351),
  ('457eb561-34e2-402d-9486-350a9cb75518','istanbul','istanbul',41.0082,28.9784),
  ('8e084da2-b6f5-4c76-b67f-afbb20581977','dubai','dubai',25.1972,55.2744),
  ('49b0f745-2711-42c6-9bdb-b363eca40620','london','london',51.5074,-0.1278),
  ('ba044858-df5b-42b1-ae34-f878c578fa60','berlin','berlin',52.5200,13.4050)
on conflict (city_id) do nothing;

alter table public.places enable row level security;
alter table public.city_keys enable row level security;
drop policy if exists places_read on public.places;
create policy places_read on public.places
  for select to authenticated using (is_active);
drop policy if exists city_keys_read on public.city_keys;
create policy city_keys_read on public.city_keys
  for select to authenticated using (true);

-- Öneri RPC: benzerlik -> küratörlü -> kullanım -> kategori boost -> merkeze yakınlık
create or replace function public.suggest_places(
  p_q text,
  p_kind text,
  p_city_id uuid default null,
  p_category text default null,
  p_limit integer default 8
) returns table (
  id uuid, name text, category text, street text, housenumber text,
  metro text, district text, website text, country_ru text,
  lat double precision, lng double precision, source text
) language plpgsql stable as $$
declare
  v_key text; v_market text; v_clat float8; v_clng float8;
  v_q text := lower(trim(p_q));
begin
  select ck.key, ck.brand_market, ck.center_lat, ck.center_lng
    into v_key, v_market, v_clat, v_clng
  from public.city_keys ck where ck.city_id = p_city_id;

  return query
  select p.id, p.name, p.category, p.street, p.housenumber,
         p.metro, p.district, p.website, p.country_ru, p.lat, p.lng, p.source
  from public.places p
  where p.is_active
    and p.kind = p_kind
    and (case p.kind
           when 'venue' then p.city_key = v_key
           when 'brand' then p.city_key = coalesce(v_market, p.city_key)
           else true end)
    and (lower(p.name) like v_q || '%'
         or lower(p.name) like '% ' || v_q || '%'
         or similarity(lower(p.name), v_q) > 0.3
         or lower(coalesce(p.name_en,'')) like v_q || '%'
         or lower(coalesce(p.name_ru,'')) like v_q || '%')
  order by
    greatest(similarity(lower(p.name), v_q),
             similarity(lower(coalesce(p.name_en,'')), v_q)) desc,
    (p.source = 'curated') desc,
    p.usage_count desc,
    (p_category is not null and p.category = p_category) desc,
    case when p.lat is not null and v_clat is not null
         then abs(p.lat - v_clat) + abs(p.lng - v_clng)
         else 9 end asc
  limit least(p_limit, 25);
end $$;

grant execute on function public.suggest_places(text, text, uuid, text, integer) to authenticated;

-- Seçim sayacı (flywheel): client doğrudan places'a yazamaz, sadece bu RPC
create or replace function public.touch_place(p_place_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.places set usage_count = usage_count + 1 where id = p_place_id;
$$;
grant execute on function public.touch_place(uuid) to authenticated;

commit;
