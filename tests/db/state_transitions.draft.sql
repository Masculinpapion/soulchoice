-- ============================================================================
-- TASLAK — HENÜZ KOŞTURULMADI, CI'DA KOŞMAZ. PROD'DA ASLA ÇALIŞTIRILMAZ.
-- ============================================================================
-- Durum-geçişi DAVRANIŞ testleri (gerçek INSERT/UPDATE + RLS). 12.08 taslağı,
-- sabah insan incelemesi için. Statik sözleşme testleri
-- (tests/edge/state_transitions_contract_test.ts) repo SQL'ini kilitler; bu
-- dosya ise kuralların gerçekten TETİKLENDİĞİNİ tek kullanımlık klon DB'de
-- kanıtlamak içindir (kural: canlı flag/veri üzerinde test değişikliği YASAK).
--
-- ÖN KOŞUL: prod dump'ından açılmış GEÇİCİ veritabanı, adı '%_test' ile
-- bitmeli (aşağıdaki kapı bunu zorlar). Örn:
--   docker exec supabase-db createdb -U postgres soulchoice_test
--   docker exec supabase-db sh -c 'pg_dump -U postgres postgres | psql -U postgres soulchoice_test'
--   docker exec -i supabase-db psql -U postgres -d soulchoice_test -v ON_ERROR_STOP=1 < tests/db/state_transitions.draft.sql
-- Çıktı: her senaryo NOTICE 'OK: ...' basar; herhangi bir ihlal EXCEPTION ile
-- durdurur (ON_ERROR_STOP sayesinde çıkış kodu != 0). Sonda ROLLBACK.
-- ============================================================================

begin;

-- ── KAPI: yanlış DB'de anında dur ──────────────────────────────────────────
do $$ begin
  if current_database() !~ '_test$' then
    raise exception 'GUVENLIK: bu betik yalniz *_test adli klon DBde kosar (su an: %)',
      current_database();
  end if;
end $$;

-- ── Fikstür: iki kullanıcı + bir aktif ilan + bir başvuru ──────────────────
-- NOT (inceleme sorusu): auth.users FK'leri ve selfie/premium ön koşulları
-- prod şemasına göre doldurulmalı; klonda en basiti mevcut GERÇEK-OLMAYAN
-- test envanterinden (test canlılık simülasyonu kullanıcıları) iki id seçmek.
-- Aşağıdaki değişkenler o karara göre doldurulacak — şimdilik yer tutucu.
\set owner_id  '''00000000-0000-0000-0000-00000000000a'''
\set applicant_id '''00000000-0000-0000-0000-00000000000b'''

create temp table _t (inv uuid, app uuid);

insert into public.invitations (owner_id, title, category, flow_type, status, expires_at, city_id)
select :owner_id, '[TEST] durum-gecisi', 'coffee', 'invite', 'active',
       now() + interval '6 hour', (select id from public.cities limit 1)
returning id into strict _placeholder; -- inceleme: RETURNING INTO psql'de yok,
-- gerçek sürümde DO bloğuna alınacak — taslakta akış gösterimi için böyle.

-- ── 1) rejected→withdrawn ENGELLİ (trg_block_withdraw_after_decision) ──────
do $$
declare v_app uuid;
begin
  select app into v_app from _t;
  update public.applications set status = 'rejected' where id = v_app; -- service_role yolu
  -- istemci kimliğine geç: authenticated + auth.uid() = applicant
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-00000000000b',
                      'role', 'authenticated')::text, true);
  begin
    update public.applications set status = 'withdrawn' where id = v_app;
    raise exception 'IHLAL: rejected→withdrawn kabul edildi (trigger dusmus)';
  exception when others then
    if sqlerrm not like '%INVALID_STATUS_TRANSITION%' then raise; end if;
    raise notice 'OK: rejected→withdrawn INVALID_STATUS_TRANSITION ile engellendi';
  end;
  reset role;
end $$;

-- ── 2) cleanup_closed_invitations: match'li ASLA silinmez, match'siz silinir ─
do $$
declare v_inv_matchless uuid; v_inv_matched uuid; n int;
begin
  -- iki closed ilan: birine match yaz, digeri bos
  -- (fikstur insert'leri gercek surumde buraya gelecek)
  select public.cleanup_closed_invitations() into n;
  if exists (select 1 from public.invitations where id = v_inv_matchless) then
    raise exception 'IHLAL: match''siz closed ilan silinmedi';
  end if;
  if not exists (select 1 from public.invitations where id = v_inv_matched) then
    raise exception 'IHLAL: MATCH''Lİ ilan silindi — sohbet basligi verisi gitti';
  end if;
  raise notice 'OK: cleanup yalniz match''siz closed ilani sildi (n=%)', n;
end $$;

-- ── 3) invitations_select RLS: kapalı ilan başvurana görünür, yabancıya değil ─
do $$
declare v_inv uuid; v_cnt int;
begin
  -- ilan closed yapılır (service_role); başvuru sahibi okuyabilmeli
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-00000000000b',
                      'role', 'authenticated')::text, true);
  select count(*) into v_cnt from public.invitations where id = v_inv;
  if v_cnt = 0 then
    raise exception 'IHLAL: basvurani oldugu kapali ilani goremiyor (11.08 vakasi geri geldi)';
  end if;
  -- yabancı (üçüncü kullanıcı) GÖREMEMELİ
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-00000000000c',
                      'role', 'authenticated')::text, true);
  select count(*) into v_cnt from public.invitations where id = v_inv;
  if v_cnt > 0 then
    raise exception 'IHLAL: kapali ilan yabanciya goruyor — RLS sizintisi';
  end if;
  reset role;
  raise notice 'OK: kapali ilan yalniz basvurana gorunur';
end $$;

-- ── 4) withdrawn→pending yalnız AKTİF ilanda (enforce_application_rules) ───
do $$
declare v_app uuid;
begin
  -- ilan closed iken withdrawn→pending DENENIR → INVITATION_NOT_OPEN beklenir
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-00000000000b',
                      'role', 'authenticated')::text, true);
  begin
    update public.applications set status = 'pending' where id = v_app;
    raise exception 'IHLAL: kapali ilanda withdrawn→pending kabul edildi';
  exception when others then
    if sqlerrm not like '%INVITATION_NOT_OPEN%' then raise; end if;
    raise notice 'OK: kapali ilanda yeniden-basvuru INVITATION_NOT_OPEN';
  end;
  reset role;
end $$;

rollback;
