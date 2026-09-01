-- 02.09.2026 — Vitrin (test) davet içeriği mevsime uyar (Mustafa kararı)
-- Sorun: Eylül'de «Сап по Москве-реке», «Пикник», «Кино под открытым небом» gibi yaz
-- kartları açık kalıyor; okuyan «bu havada ne alaka» deyip sahte olduğunu anlıyor.
-- Çözüm: test_invitation_variants.season (all|warm|cold) + feature_flags.test_content_season
-- ({"mode":"auto"|"warm"|"cold"}; auto = MSK takvimi May–Ağu warm, diğer cold);
-- simulate_test_liveliness yalnız mevsime uygun varyantı seçer; açık mevsim-dışı test
-- kartları süresi geçmiş sayılıp bir sonraki tikte yeniden doğar.
begin;

alter table public.test_invitation_variants
  add column if not exists season text not null default 'all'
  check (season in ('all','warm','cold'));

insert into public.feature_flags (key, value)
values ('test_content_season', '{"mode":"auto"}'::jsonb)
on conflict (key) do nothing;

-- Yaz-bağımlı varyantlar (sap/yat/açık hava sinema-sahne/piknik/plaj/veranda-teras/
-- çeşme/dondurma-limonata/bisiklet-kaykay-streetball-petank/su kenarı gün batımı+pled)
update public.test_invitation_variants set season = 'warm'
 where id in (45,56,103,131,133,134,169,173,175,508,526,656,663,686,701,706,721,732,739,754,758,761,780,781,783,787,799,809,811,829,840,846);

CREATE OR REPLACE FUNCTION public.simulate_test_liveliness()
 RETURNS TABLE(refreshed_invitations integer, seeded_applications integer, touched_users integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now       timestamptz := now();
  v_msk_hour  int := extract(hour from v_now at time zone 'Europe/Moscow')::int;
  -- Bypass/Mustafa hesabı: motor hiçbir yazmada bu kullanıcıya dokunmaz
  v_bypass    uuid := '279e44e0-f09e-4b31-ad20-94966aa6f6bb';
  -- Демо hesabı (is_test_user=TRUE!): Apple review sahnesi — motor ASLA dokunmaz
  -- (19.08 denetimi: yalnız demo-autoextend cron'u koruyordu; açık guard eklendi)
  v_demo      uuid := '385ea0eb-2089-4fd2-8883-8a47a39da29a';
  r           record;
  v_created   timestamptz;
  v_expires   timestamptz;
  n_apps      int;
  v_refreshed int := 0;
  v_apps      int := 0;
  v_touched   int := 0;
  -- İçerik rotasyonu (19.08.2026): kişi başına birden çok davet varyantı
  v_nvar      int;
  v_cur       int;
  v_next      int;
  v_var       record;
  v_season    text;   -- 02.09: vitrin mevsimi (warm/cold)
  v_evbase    timestamptz;
  v_evdate    timestamptz;
begin
  -- 02.09.2026 (Mustafa): vitrin içeriği mevsime uyar — «Сап по Москве-реке» Eylül
  -- yağmurunda sahte olduğunu ele veriyordu. feature_flags.test_content_season
  -- {"mode":"auto"|"warm"|"cold"}; auto = Moskova takvimi: Mayıs–Ağustos warm, diğer cold.
  select coalesce(value->>'mode', 'auto') into v_season
    from public.feature_flags where key = 'test_content_season';
  if v_season is null or v_season not in ('warm','cold') then
    v_season := case when extract(month from (v_now at time zone 'Europe/Moscow')) between 5 and 8
                     then 'warm' else 'cold' end;
  end if;
  -- ── 1) Davet rebirth: dolan kart ANINDA yenilenir (v2 — ölü bekleme yok) ──
  for r in
    select u.id as user_id, u.gender, u.city_id,
           i.id as inv_id, i.status as inv_status, i.flow_type,
           i.expires_at, i.event_date
    from public.users u
    left join lateral (
      select id, status, flow_type, expires_at, event_date
      from public.invitations
      where owner_id = u.id
      order by expires_at desc
      limit 1
    ) i on true
    where u.is_test_user = true
      and u.id <> v_bypass
      and u.id <> v_demo
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

    -- İÇERİK ROTASYONU (19.08.2026, Mustafa kararı): test kartı yeniden doğarken
    -- kişinin sıradaki davet varyantını alır (kategori/başlık/açıklama/mekân/saat)
    -- → "aynı kişi aynı kafede her gün" sahte sinyali kalkar. Varyant yoksa
    -- (ör. Демо) içerik aynen kalır. Sıra: test_rotation_state (kişi başına seq).
    select count(*) into v_nvar
      from public.test_invitation_variants where owner_id = r.user_id;
    if v_nvar > 1 then
      select seq into v_cur from public.test_rotation_state where owner_id = r.user_id;
      -- 22.08 (Mustafa: «Ресторан'da 2-3 kişi var; kişi ilk gördüğüne tıklar,
      -- 3 kart görürse boş app der gider»): kör sıra yerine AĞIRLIKLI DİLİM
      -- DENGESİ — kişinin varyantları arasından, bu şehir+akış+cinsiyet
      -- diliminde doluluk/hedef oranı EN DÜŞÜK kategori seçilir. Hedefler çip
      -- görünürlüğüne göre (food 6, bar/concert 5, coffee/walk 4, travel/
      -- culture/cinema 3, niş 2): vitrindeki ilk kategoriler her zaman dolu
      -- kalır, walk 11'e şişemez. Eşitlikte çip sırası, sonra doğal rotasyon.
      select v.* into v_var
        from public.test_invitation_variants v
        left join lateral (
          select count(*) as n
            from public.invitations ai
            join public.users au on au.id = ai.owner_id
           where ai.status = 'active'
             and ai.expires_at > v_now
             and ai.category = v.category
             and ai.city_id = r.city_id
             and ai.flow_type = r.flow_type
             and au.is_test_user = true
             and au.gender = r.gender
             and ai.id <> r.inv_id
        ) cnt on true
       where v.owner_id = r.user_id
         and (v.season = 'all' or v.season = v_season)   -- 02.09 mevsim filtresi
       order by (cnt.n::numeric / case v.category
                   when 'food'    then 6
                   when 'bar'     then 5
                   when 'concert' then 5
                   when 'coffee'  then 4
                   when 'walk'    then 4
                   when 'travel'  then 3
                   when 'culture' then 3
                   when 'cinema'  then 3
                   else 2 end) asc,
                case v.category
                   when 'food' then 0 when 'bar' then 1 when 'concert' then 2
                   when 'travel' then 3 else 4 end asc,
                ((v.seq - coalesce(v_cur, 0) - 1 + v_nvar) % v_nvar) asc
       limit 1;
      v_next := v_var.seq;
      if v_var.seq is not null then
        -- event_date: expires+1h'den sonraki ilk "varyant saati" (MSK) — süre kuralı
        -- expires_at ≤ event_date − 1h (17.08) korunur.
        v_evbase := v_expires + interval '1 hour';
        v_evdate := (date_trunc('day', v_evbase at time zone 'Europe/Moscow')
                     + make_interval(hours => v_var.ev_hour)) at time zone 'Europe/Moscow';
        if v_evdate < v_evbase then v_evdate := v_evdate + interval '1 day'; end if;

        update public.invitations i
           set category    = v_var.category,
               title       = v_var.title,
               description = v_var.description,
               venue_name  = v_var.venue_name,
               event_date  = v_evdate
         where i.id = r.inv_id
           and exists (select 1 from public.users ou
                       where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard

        insert into public.test_rotation_state (owner_id, seq)
        values (r.user_id, v_next)
        on conflict (owner_id) do update set seq = excluded.seq, updated_at = now();
      end if;
    end if;

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
        and tu.id <> v_demo
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
      where is_test_user = true and id <> v_bypass and id <> v_demo
        and is_deleted = false and banned = false
      order by random()
      limit 2 + floor(random()*3)::int
    ) pick
    where u.id = pick.id;
    get diagnostics v_touched = row_count;
  end if;

  return query select v_refreshed, v_apps, v_touched;
end;
$function$;

-- Şu an açık olan mevsim-dışı test kartları: süresi geçmiş say → sonraki tikte rebirth
-- (Демо sahibi 385ea0eb hariç; engine zaten ona dokunmaz).
with eff as (
  select case
           when coalesce((select value->>'mode' from public.feature_flags where key='test_content_season'),'auto') in ('warm','cold')
             then (select value->>'mode' from public.feature_flags where key='test_content_season')
           when extract(month from (now() at time zone 'Europe/Moscow')) between 5 and 8 then 'warm'
           else 'cold' end as s
)
update public.invitations i
   set expires_at = now() - interval '1 minute'
  from public.users u, public.test_invitation_variants v, eff
 where u.id = i.owner_id and u.is_test_user = true
   and u.id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'
   and i.status = 'active'
   and v.owner_id = i.owner_id and v.title = i.title
   and v.season <> 'all' and v.season <> eff.s;

commit;
