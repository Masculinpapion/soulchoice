-- 12.07.2026 — Akıllı kırpma: yüz odak noktası kolonları
-- (Prod'a 12.07.2026 uygulandı; backfill ops/face_focus.py ile yapıldı.)
alter table public.user_photos
  add column if not exists face_focus_x real,
  add column if not exists face_focus_y real;
comment on column public.user_photos.face_focus_x is
  'Yüz merkezi x (0-1 fraksiyon); null=işlenmedi, -1=yüz yok/bozuk dosya';
