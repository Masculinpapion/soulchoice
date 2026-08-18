-- 18.08.2026 — rls_exposure_fix eki: invitations_select / photos_select politikaları TAM metinle
-- (rol + USING) yeniden yazılır. Önceki dosyadaki `alter policy … to authenticated` canlıda USING'i
-- korudu (davranış doğru), ancak repo bekçi testi (tests/edge/state_transitions_contract_test.ts #3)
-- politikayı içeren SON migration'da has_application_to istisnasını metin olarak arar → burada açıkça
-- yer alır. Canlıda idempotent (aynı rol + aynı USING).
begin;

ALTER POLICY invitations_select ON public.invitations
TO authenticated
USING (((status = 'active' AND owner_id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'::uuid)
        OR (owner_id = auth.uid())
        OR public.has_application_to(id)));

ALTER POLICY photos_select ON public.user_photos
TO authenticated
USING (((moderation_status <> 'rejected'::text) OR (user_id = auth.uid())));

commit;
