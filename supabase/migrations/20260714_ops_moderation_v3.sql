-- 20260714_ops_moderation_v3.sql
-- audit_log RLS düzeltmesi: RLS policy'siz açılınca ops_moderator SELECT grant'ine
-- rağmen 0 satır görüyordu (panel "bugün işlenen" sayacı ve audit listesi boş kalıyordu).
-- Salt-okuma policy'si eklendi; INSERT hâlâ sadece SECURITY DEFINER RPC'lerden.
create policy audit_read on public.audit_log for select to ops_moderator using (true);
