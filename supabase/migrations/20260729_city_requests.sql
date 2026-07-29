-- "Şehrim listede yok" kayıtları (29.07, madde A5) — hangi şehri açacağımıza
-- veriyle karar vermek için; kullanıcıya "şehrin açılınca haber vereceğiz" denir.
CREATE TABLE IF NOT EXISTS public.city_requests (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  city_text  text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.city_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY cr_insert ON public.city_requests FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY cr_select_own ON public.city_requests FOR SELECT
  USING (user_id = auth.uid());

GRANT SELECT ON public.city_requests TO ops_moderator;
