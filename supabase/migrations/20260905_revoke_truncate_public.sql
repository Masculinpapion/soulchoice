-- 05.09.2026 — Hijyen (05.09 açık iş #4): anon/authenticated rollerinde public şemadaki
-- 30 tabloda TRUNCATE yetkisi vardı (Supabase varsayılanı: ALL). PostgREST TRUNCATE
-- bilmediği için REST'ten tetiklenemez, ama istemci anahtarıyla erişilen bir rolün
-- tablo boşaltma yetkisi taşımasının hiçbir gereği yok. service_role/postgres etkilenmez.
-- pg_default_acl de aynı yetkiyi YENİ tablolara veriyordu → gelecek için de kapatılır
-- (postgres ve supabase_admin sahipli tablolar için ayrı ayrı).
-- Uygulama (superuser gerekir — ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin):
--   docker exec -i supabase-db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < bu_dosya
-- Baseline (--no-privileges) etkilenmez; doğrulama:
--   select count(*) from information_schema.role_table_grants
--    where table_schema='public' and privilege_type='TRUNCATE' and grantee in ('anon','authenticated');  -- 0
revoke truncate on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public revoke truncate on tables from anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke truncate on tables from anon, authenticated;
