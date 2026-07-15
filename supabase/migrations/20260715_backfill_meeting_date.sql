-- Buluşma/arşiv mekaniğini canlandırma (docs/product-logic.md §7): kabul anında
-- match.meeting_date artık ilanın event_date'inden set ediliyor (app: decision_screen).
-- Bu migration, o düzeltmeden ÖNCE oluşmuş match'lerin meeting_date'ini geriye
-- dönük doldurur (idempotent: yalnız NULL olanlar + event_date'i olan ilanlar).
update public.matches m
   set meeting_date = i.event_date
  from public.invitations i
 where m.invitation_id = i.id
   and m.meeting_date is null
   and i.event_date is not null;
