-- 11.08.2026 — İPTAL EDİLDİ (aynı gece, Mustafa nihai kararı).
-- Kısa süreliğine 30 gün saklama denendi (ЗАВЕРШЕНО kartı için); nihai karar:
-- profildeki "Başvurularım" ANLIK PANO — ilan kapanınca kart düşer, saklamaya
-- gerek yok. Aşağıdaki tanım 15.07 orijinal davranışın aynısıdır (hemen silme);
-- prod'a yeniden uygulandı. Match'li ilana yine ASLA dokunulmaz.
create or replace function public.cleanup_closed_invitations()
returns integer language plpgsql security definer set search_path = public, pg_temp as $fn$
declare n integer;
begin
  with del as (
    delete from public.invitations i
    where i.status = 'closed'
      and not exists (select 1 from public.matches m where m.invitation_id = i.id)
    returning 1
  )
  select count(*) into n from del;
  return n;
end $fn$;
