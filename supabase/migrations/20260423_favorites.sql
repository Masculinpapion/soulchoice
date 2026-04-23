-- favorites table: allows users to star/favorite other users
CREATE TABLE IF NOT EXISTS favorites (
  id                uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  favorited_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at        timestamptz DEFAULT now(),
  UNIQUE(user_id, favorited_user_id)
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS favorites_user_id_idx ON favorites(user_id);
CREATE INDEX IF NOT EXISTS favorites_favorited_user_id_idx ON favorites(favorited_user_id);

-- Row Level Security
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own favorites
CREATE POLICY "favorites_own_access"
  ON favorites FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
