-- 11.08.2026 — Kabul edilen başvurunun davetiyesi kapanınca profil kartında
-- başlık/isim kayboluyordu ("—" + boş isim): invitations_select yalnız
-- active davetiyeleri gösteriyor, kapanan davetiyeyi başvuran artık
-- okuyamıyordu (embed join null). Başvurusu olan kullanıcı davetiyeyi
-- durumdan bağımsız görebilmeli — akıbet takibi (🟠2) + detay ekranı.
-- NOT: applications_select politikası invitations'a subquery atıyor; buradan
-- applications'a düz subquery dönersek karşılıklı RLS özyinelemesi oluşur —
-- SECURITY DEFINER fonksiyon RLS'i atlayıp döngüyü kırar.
-- Eski tanım (geri dönüş): bkz. 20260801_demo_feed_hide.sql
create or replace function public.has_application_to(inv uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from applications
    where invitation_id = inv and applicant_id = auth.uid()
  );
$$;

revoke all on function public.has_application_to(uuid) from public;
grant execute on function public.has_application_to(uuid) to authenticated;

ALTER POLICY invitations_select ON public.invitations
USING (((status = 'active' AND owner_id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'::uuid)
        OR (owner_id = auth.uid())
        OR public.has_application_to(id)));
