-- 17.09.2026 — invitations_select RLS'inden cinsiyet şartı KALDIRILDI.
-- Vaka: Apple 4.3(b) 6. red. iOS «açık akış» paketi (openFeedMode) istemci
-- filtresini kaldırdı ama sunucu politikası kartları yine karşı cinse
-- kısıtlıyordu: erkek demo hesabı yalnız kadın kartlarını görüyordu
-- (demo şehrinde 3 erkek kartı hiç inmiyordu). Bu cinsiyet şartı repoda
-- YOKTU — sunucuya 18.08 öncesi elle eklenmişti (şema kayması,
-- /root/backups/schema-pre-antifraud-20260818.sql'de görülür).
-- Karşı-cins/yaş süzgeci bir güvenlik sınırı değil, ürün tercihi:
-- Android istemcisi kendi sorgusunda (invitations_provider .or + istemci
-- süzgeci) uygulamaya devam eder → Android/RuStore/Play davranışı değişmez.
-- iOS'ta herkes herkesin planını görür.
-- Eski tanım (geri dönüş):
--   USING (((status='active' AND owner_id <> '385ea0eb-…'::uuid
--            AND ((select u.gender from users u where u.id=auth.uid()) is null
--                 or (select o.gender from users o where o.id=invitations.owner_id)
--                    is distinct from (select u.gender from users u where u.id=auth.uid())))
--           OR owner_id = auth.uid() OR has_application_to(id)))
-- Yeni tanım = 20260811_applicant_sees_closed_invitation.sql ile birebir.
ALTER POLICY invitations_select ON public.invitations
USING (((status = 'active' AND owner_id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'::uuid)
        OR (owner_id = auth.uid())
        OR public.has_application_to(id)));
