-- 20260731: Migration bütünlüğü (31.07 denetimi A1/A2/A3/C1).
-- Prod'da elle oluşturulmuş üç nesnenin + oferta_version seed'inin
-- birebir dökümü — temiz ortam (CI/staging) migrations'tan kurulabilsin.
-- Kaynak: prod pg_get_functiondef + pg_dump --schema-only (31.07.2026).
-- Prod'a yeniden uygulanması güvenlidir (IF NOT EXISTS / OR REPLACE / ON CONFLICT).

CREATE TABLE IF NOT EXISTS public.call_otps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:05:00'::interval) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    attempts integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT notifications_type_check CHECK ((type = ANY (ARRAY['new_application'::text, 'selected'::text, 'not_selected'::text, 'new_message'::text, 'selfie_approved'::text, 'selfie_rejected'::text, 'meeting_reminder'::text, 'feedback_request'::text, 'selection_reminder'::text, 'premium_activated'::text])))
);

DO $do$ BEGIN
ALTER TABLE ONLY public.call_otps
    ADD CONSTRAINT call_otps_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

CREATE INDEX IF NOT EXISTS idx_call_otps_phone ON public.call_otps USING btree (phone);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE POLICY "Service role all notifications" ON public.notifications USING ((auth.role() = 'service_role'::text));

CREATE POLICY "Users delete own notifications" ON public.notifications FOR DELETE USING ((user_id = auth.uid()));

CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT USING ((user_id = auth.uid()));

CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING ((user_id = auth.uid()));

ALTER TABLE public.call_otps ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY service_manage_call_otps ON public.call_otps USING ((auth.role() = 'service_role'::text));
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $do$;

GRANT ALL ON TABLE public.call_otps TO anon;
GRANT ALL ON TABLE public.call_otps TO authenticated;
GRANT ALL ON TABLE public.call_otps TO service_role;

GRANT ALL ON TABLE public.notifications TO anon;
GRANT ALL ON TABLE public.notifications TO authenticated;
GRANT ALL ON TABLE public.notifications TO service_role;


CREATE OR REPLACE FUNCTION public.match_and_select(p_application_id uuid, p_invitation_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_applicant_id uuid;
  v_match_id     uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM invitations
    WHERE id = p_invitation_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  PERFORM id FROM invitations
    WHERE id = p_invitation_id AND status IN ('active', 'selecting')
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_available';
  END IF;

  SELECT applicant_id INTO v_applicant_id
    FROM applications WHERE id = p_application_id;

  IF v_applicant_id IS NULL THEN
    RAISE EXCEPTION 'application_not_found';
  END IF;

  INSERT INTO matches (invitation_id, user1_id, user2_id)
    VALUES (p_invitation_id, auth.uid(), v_applicant_id)
    RETURNING id INTO v_match_id;

  UPDATE applications
    SET status = 'accepted', selected_at = NOW()
    WHERE id = p_application_id;

  RETURN v_match_id;
END;
$function$

;

-- C1: paywall'ın okuduğu oferta sürümü (prod değeriyle birebir)
INSERT INTO feature_flags(key, value) VALUES ('oferta_version', '{"v": "2026-07-09"}'::jsonb)
  ON CONFLICT (key) DO NOTHING;
