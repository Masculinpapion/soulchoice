-- Mesaj tepkileri (29.07.2026, Mustafa onaylı v1)
-- Kullanıcı başına mesaj başına 1 tepki; 6 sabit emoji; push YOK (sessiz).
-- Realtime: chat ekranı match_id filtresiyle dinler; DELETE payload'ının
-- match_id taşıması için REPLICA IDENTITY FULL şart.

CREATE TABLE IF NOT EXISTS public.message_reactions (
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
  match_id   uuid NOT NULL REFERENCES public.matches(id)  ON DELETE CASCADE,
  emoji      text NOT NULL CHECK (emoji IN ('❤️','😂','👍','😮','😢','🔥')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reactions_match
  ON public.message_reactions (match_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;

-- Yalnız match'in iki üyesi görür; herkes yalnız kendi tepkisini yazar/siler.
CREATE POLICY mr_select ON public.message_reactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.matches m
          WHERE m.id = match_id
            AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid()))
);
CREATE POLICY mr_insert ON public.message_reactions FOR INSERT WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (SELECT 1 FROM public.matches m
              WHERE m.id = match_id
                AND (m.user1_id = auth.uid() OR m.user2_id = auth.uid()))
);
CREATE POLICY mr_update ON public.message_reactions FOR UPDATE
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY mr_delete ON public.message_reactions FOR DELETE
  USING (user_id = auth.uid());

ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
