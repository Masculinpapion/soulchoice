-- 19.08.2026 — Test canlılık motoru: yeniden doğan test kartındaki GERÇEK
-- kullanıcı başvuruları da silinir (Mustafa kararı, sahte-sinyal düzeltmesi).
-- Sorun: simulate_test_liveliness() dolan test kartını aynı satırda tazeliyor,
-- test→test başvuruları silip yenilerini ekliyor ama gerçek kullanıcının
-- başvurusuna dokunmuyordu → "Başvurularım"da 21 gün reaksiyonsuz "Bekliyor"
-- (kanıt: 279e44e0 → Ангелина/Дарина, 29.07'den beri pending).
-- Gerçek akışla tutarlılık: matchsiz closed ilan cleanup ile SİLİNİR, başvurular
-- CASCADE ile gider; yeniden doğan test kartı = yeni ilan → eski başvuru gider.
-- Kullanıcı isterse yeni karta temiz başvurur (trg_reset_created_at_on_reapply);
-- ücretsiz hak bayrağı (free_application_used) kullanıcıda → iade olmaz.
-- Demo daveti (Mustafa hesabı, is_test_user=false) kapsam DIŞI — etkilenmez.
-- Tek kaynak: ops/simulate_test_liveliness.sql (aynı gövde).
-- Prod: supabase_admin ile koş; yedek /root/backups/fn_simulate_test_liveliness_pre_20260819.sql

begin;

create or replace function public.simulate_test_liveliness()
returns table(refreshed_invitations int, seeded_applications int, touched_users int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now       timestamptz := now();
  v_msk_hour  int := extract(hour from v_now at time zone 'Europe/Moscow')::int;
  -- Bypass/Mustafa hesabı: motor hiçbir yazmada bu kullanıcıya dokunmaz
  v_bypass    uuid := '279e44e0-f09e-4b31-ad20-94966aa6f6bb';
  r           record;
  v_created   timestamptz;
  v_expires   timestamptz;
  n_apps      int;
  v_refreshed int := 0;
  v_apps      int := 0;
  v_touched   int := 0;
begin
  -- ── 1) Davet rebirth: dolan kart ANINDA yenilenir (v2 — ölü bekleme yok) ──
  for r in
    select u.id as user_id, u.gender, u.city_id,
           i.id as inv_id, i.status as inv_status, i.expires_at, i.event_date
    from public.users u
    left join lateral (
      select id, status, expires_at, event_date
      from public.invitations
      where owner_id = u.id
      order by expires_at desc
      limit 1
    ) i on true
    where u.is_test_user = true
      and u.id <> v_bypass
      and u.is_deleted = false
      and u.banned = false
      and i.id is not null                -- davetsiz test kullanıcısını fonksiyon YARATMAZ
                                          -- (ilk davet add-test-user.sh'ın işi)
  loop
    -- Aktif ve süresi dolmamış davet varsa dokunma.
    -- Expiry-race fix: 2 dk tolerans — cron koşarken dolmak üzere olanlar da yenilenir.
    if r.inv_status = 'active' and r.expires_at > v_now + interval '2 minutes' then
      continue;
    end if;

    -- Rebirth damgaları: hep "az önce / 1 saat önce" hissi + doğal geri sayım
    v_created := v_now - (random() * interval '90 minutes');
    v_expires := v_created + interval '20 hours' + (random() * interval '6 hours');

    update public.invitations i
    set status     = 'active',
        created_at = v_created,
        expires_at = v_expires,
        -- event_date geçmişte/expiry içinde kalmasın: saat korunur, gün ileri itilir
        event_date = case
          when i.event_date > v_expires then i.event_date
          else i.event_date
             + (ceil(extract(epoch from (v_expires - i.event_date)) / 86400.0)::int
                * interval '1 day')
        end
        -- selection_deadline'a DOKUNULMAZ (D1 teyitli 10.07): job 1 onu yalnız
        -- active→selecting geçişinde expires_at+48h yapar; aktif davette inert.
        -- selecting/closed'a düşmüş test daveti bu update ile zaten active'e döner.
    where i.id = r.inv_id
      and exists (select 1 from public.users ou
                  where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard
    v_refreshed := v_refreshed + 1;

    -- Eski başvuruları sil — TEST ve GERÇEK kullanıcılarınki birlikte (19.08.2026,
    -- Mustafa kararı). Gerekçe: gerçek akışta dolan matchsiz ilan closed→SİLİNİR
    -- ve başvurular CASCADE ile gider; yeniden doğan test kartı "yeni ilan"dır,
    -- gerçek kullanıcının eski başvurusu aynı satırda sonsuza dek 'pending'
    -- kalıyordu (Başvurularım'da 21 gün "Bekliyor" = sahte sinyal). selected/
    -- accepted ASLA silinmez (test sahibi seçmez; olası match korunur).
    delete from public.applications a
    where a.invitation_id = r.inv_id
      and a.status in ('pending', 'withdrawn', 'rejected', 'expired');

    -- 0–4 taze test başvuranı ek (aynı şehir, karşı cinsiyet, davet doğumundan sonra damga)
    n_apps := floor(random()*5)::int;
    with fresh as (
      insert into public.applications (invitation_id, applicant_id, status, created_at)
      select r.inv_id, tu.id, 'pending',
             v_created + (random() * (v_now - v_created))
      from public.users tu
      where tu.is_test_user = true
        and tu.id <> r.user_id
        and tu.id <> v_bypass
        and tu.city_id = r.city_id
        and tu.gender is distinct from r.gender
        and tu.is_deleted = false
        and tu.banned = false
      order by random()
      limit n_apps
      on conflict (invitation_id, applicant_id) do nothing
      returning applicant_id, created_at
    )
    -- Başvuranların keşfet tazeliği: last_active_at ≈ başvuru anı
    update public.users u
    set last_active_at = greatest(coalesce(u.last_active_at, f.created_at), f.created_at)
    from fresh f
    where u.id = f.applicant_id and u.is_test_user = true;

    get diagnostics n_apps = row_count;  -- update edilen başvuran sayısı
    v_apps := v_apps + n_apps;

    -- Davet sahibinin tazeliği
    update public.users
    set last_active_at = v_created + (random() * (v_now - v_created))
    where id = r.user_id and is_test_user = true;
  end loop;

  -- ── 2) Keşfet tazelik nabzı: uyanık saatlerde koşu başına 2–4 rastgele
  --       test kullanıcısına "az önce aktifti" damgası (davetten bağımsız) ──
  if v_msk_hour between 8 and 23 then
    update public.users u
    set last_active_at = v_now - (random() * interval '30 minutes')
    from (
      select id from public.users
      where is_test_user = true and id <> v_bypass
        and is_deleted = false and banned = false
      order by random()
      limit 2 + floor(random()*3)::int
    ) pick
    where u.id = pick.id;
    get diagnostics v_touched = row_count;
  end if;

  return query select v_refreshed, v_apps, v_touched;
end;
$$;

-- Tek seferlik temizlik: test kartlarında bekleyen/geri çekilmiş GERÇEK
-- başvurular (bugüne kadar birikenler; selected/accepted korunur).
delete from public.applications a
using public.invitations i, public.users o, public.users ap
where i.id = a.invitation_id
  and o.id = i.owner_id and o.is_test_user = true
  and ap.id = a.applicant_id and ap.is_test_user = false
  and a.status in ('pending', 'withdrawn', 'rejected', 'expired');

commit;
