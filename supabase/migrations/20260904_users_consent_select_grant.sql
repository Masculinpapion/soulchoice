-- 04.09.2026 — E2E kritik yol testinin İLK koşusunda yakalandı (23.08 sınıfı gizli kayıt kırığı):
-- 03.09 kolon-izni daraltması (20260903_users_private_columns.sql) consent_given_at/consent_version'ı
-- SELECT listesinden çıkarmıştı. profile_setup_screen'in users UPSERT'i (INSERT ... ON CONFLICT DO UPDATE
-- SET consent_given_at = EXCLUDED.consent_given_at) Postgres kuralı gereği bu kolonlarda SELECT ister →
-- "permission denied for table users" → hiçbir yeni kullanıcı profil kurulumunu bitiremezdi (782/233/Play).
-- Consent damgası hassas veri değildir (RLS zaten yalnız satır görünürlüğünü belirler); SELECT geri verilir.
begin;
grant select (consent_given_at, consent_version) on public.users to authenticated;
commit;
