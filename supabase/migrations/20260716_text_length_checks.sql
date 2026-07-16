-- 16.07: başlık/açıklama uzunluğu artık SUNUCUDA da sınırlı (Mustafa onayı).
-- İstemci limitleri (60/300) zaten var; bu kısıt resmi uygulamayı aşıp API'ye
-- doğrudan yazan istemcilere karşı veri hijyeni sağlar. Mevcut veri uyumlu
-- (16.07 ölçümü: title max 32). Ekranlar zaten ellipsis ile korunuyor.
-- NOT: tablo sahibi supabase_admin — psql -U supabase_admin ile uygula
-- (postgres rolü "must be owner" hatası verir; 16.07'de öyle uygulandı).

begin;

alter table public.invitations
  add constraint invitations_title_len_check
  check (char_length(title) <= 60);

alter table public.invitations
  add constraint invitations_description_len_check
  check (description is null or char_length(description) <= 300);

commit;

notify pgrst, 'reload schema';
