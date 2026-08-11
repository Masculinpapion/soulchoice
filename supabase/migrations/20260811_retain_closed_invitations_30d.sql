-- 11.08.2026 — Mustafa kararı: kapalı ilan HEMEN silinmez, 30 gün saklanır.
-- Sebep: başvuranın profilindeki kart CASCADE ile 1 saat içinde yok oluyordu
-- ("seçtiğimiz kişiler nereye kayboluyor?"). Yeni akış: seçilmeyen başvuru
-- kartı nötr "ЗАВЕРШЕНО" rozetiyle 30 gün görünür, sonra ilanla birlikte
-- sessizce düşer. Feed etkilenmez (yalnız active listelenir); match'i olan
-- ilana yine ASLA dokunulmaz. Eski davranış: 20260715_cleanup_closed_invitations.sql
create or replace function public.cleanup_closed_invitations()
returns integer language plpgsql security definer set search_path = public, pg_temp as $fn$
declare n integer;
begin
  with del as (
    delete from public.invitations i
    where i.status = 'closed'
      and i.expires_at < now() - interval '30 days'
      and not exists (select 1 from public.matches m where m.invitation_id = i.id)
    returning 1
  )
  select count(*) into n from del;
  return n;
end $fn$;
