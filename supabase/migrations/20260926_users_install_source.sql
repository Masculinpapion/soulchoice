-- Kurulum kaynağı (26.09.2026, Play yayını günü, Mustafa kararı: «her gelen
-- kullanıcının Play/RuStore/App Store'dan mı geldiğini bilelim»).
-- users.install_source: istemci savePushToken'da app_build ile birlikte yazar
-- (package_info_plus installerStore → play | rustore | apk | appstore |
-- testflight | unknown). authenticated'ın UPDATE'i tablo seviyesinde,
-- privilege-escalation tetikleyicisi bu kolonu izlemez — ek grant gerekmez.
alter table public.users add column if not exists install_source text;
comment on column public.users.install_source is
  'Kurulum kaynağı: play | rustore | apk | appstore | testflight | unknown (26.09.2026)';

-- Geriye doldurma: build 845 yalnız Google Play üretiminde dağıtıldı
-- (landing APK 16–26.09 arası 844 idi; 845 asla siteye konmadı) → kesin play.
-- 844/830 ve altı RuStore, kapalı test ve landing APK arasında belirsiz → boş kalır.
update public.users set install_source = 'play'
 where install_source is null and app_build = 845;

-- Huni kaynak bazında (v_funnel ile aynı tanımlar, install_source'a göre kırılım).
create or replace view public.v_funnel_by_source as
select coalesce(u.install_source, 'unknown') as source,
       count(*)::int as registered,
       count(*) filter (where u.selfie_status = 'approved')::int as selfie_approved,
       count(*) filter (where exists (select 1 from applications a where a.applicant_id = u.id))::int as applied,
       count(*) filter (where exists (select 1 from matches m where m.user1_id = u.id or m.user2_id = u.id))::int as matched
  from users u
 where not u.is_test_user and not u.is_deleted
 group by 1
 order by registered desc;

grant select on public.v_funnel_by_source to ops_moderator;
