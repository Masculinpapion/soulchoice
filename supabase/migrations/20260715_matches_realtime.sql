-- Yeni eşleşme Mesajlar listesinde anlık görünsün: matches tablosunu realtime
-- publication'a ekle (messages zaten ekliydi). RLS filtreli — her client yalnız
-- kendi match'lerinin insert event'ini alır.
alter publication supabase_realtime add table public.matches;
