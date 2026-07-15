-- Çift yönlü engelleme (docs/product-logic.md §12): kullanıcı, engellediği kadar
-- KENDİSİNİ engelleyen kişilerin ilanlarını da görmemeli. blocks SELECT RLS'i
-- yalnız blocker_id=auth.uid() satırlarına izin verdiğinden istemci "beni kim
-- engelledi" satırlarını okuyamaz. SECURITY DEFINER RPC birleşik gizli-id
-- listesi döndürür (ham blocks satırlarını / "kim engelledi" bilgisini ifşa etmez).
create or replace function public.hidden_from_feed()
returns table(user_id uuid)
language sql
security definer
stable
as $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid()
$$;

revoke all on function public.hidden_from_feed() from public;
grant execute on function public.hidden_from_feed() to authenticated;
