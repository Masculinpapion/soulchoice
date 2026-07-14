-- 20260715_matches_invitation_setnull.sql
-- matches.invitation_id FK: CASCADE → SET NULL.
-- SEBEP: eşleşen kullanıcıların sohbeti davet süresinden BAĞIMSIZ yaşamalı.
-- Önceki CASCADE'de davet silinince matches (CASCADE) + messages (match_id CASCADE)
-- gidiyordu → eşleşme+sohbet kaybı. SET NULL ile davet hangi yolla silinirse silinsin
-- (cron/manuel/admin) eşleşme+sohbet asla gitmez, invitation_id NULL olur.
-- App zaten hazır: chat_screen invitation'ı null-safe okur (inv?, invitationId != null guard);
-- matches_provider invitation_id'yi hiç seçmez. App değişikliği GEREKMEDİ.
-- Prod'da uygulandı + canlı davranış testiyle doğrulandı 15.07.2026.
alter table public.matches drop constraint matches_invitation_id_fkey;
alter table public.matches add constraint matches_invitation_id_fkey
  foreign key (invitation_id) references public.invitations(id) on delete set null;
