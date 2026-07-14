-- 20260715_cleanup_closed_invitations.sql
-- Süresi dolup closed olan davetleri otomatik temizle — AMA eşleşmesi olanlara
-- ASLA dokunma (matches.invitation_id CASCADE olduğu için silme sohbeti götürür).
-- Cron: '5 * * * *' (invitation-selecting-to-closed 00. dk'dan sonra çalışsın).
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

-- select cron.schedule('cleanup-closed-invitations', '5 * * * *',
--   $c$select public.cleanup_closed_invitations()$c$);  -- prod'da uygulandı 15.07.2026
