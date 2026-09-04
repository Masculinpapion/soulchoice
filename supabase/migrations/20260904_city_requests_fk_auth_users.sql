-- «Моего города нет» talebi (29.07) doğduğundan beri KIRIKTI (04.09 Алёна vakası, tablo 0 satır):
-- buton sihirbazın 3. adımında, public.users satırı ise 9. adımda (consent) oluşuyor → FK 23503 → PostgREST 409,
-- uygulama hatayı yutup «teşekkürler» gösteriyordu. Kimlik auth.uid()'dir; FK auth.users'a bağlanır
-- (hesap silinince CASCADE aynı kalır). RLS (cr_insert: user_id = auth.uid()) değişmez.
ALTER TABLE public.city_requests DROP CONSTRAINT IF EXISTS city_requests_user_id_fkey;
ALTER TABLE public.city_requests
  ADD CONSTRAINT city_requests_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
