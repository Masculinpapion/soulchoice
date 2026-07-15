-- 🟡4: push'lar alıcının dilinde gitsin — app kendi dilini buraya yazar,
-- send-notification şablon seçiminde okur (yoksa ru).
alter table public.users add column if not exists locale text;
notify pgrst, 'reload schema';
