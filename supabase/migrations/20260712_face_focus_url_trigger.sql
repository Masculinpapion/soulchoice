-- 12.07.2026 — foto URL'i değişirse yüz odağı yeniden hesaplansın
-- (Uygulandı: prod 12.07. Sebep: URL swap'te bayat odak kalıyordu — Виолетта vakası.)
create or replace function public.reset_face_focus_on_url_change()
returns trigger language plpgsql as $fn$
begin
  if new.url is distinct from old.url then
    new.face_focus_x := null;
    new.face_focus_y := null;
  end if;
  return new;
end $fn$;

drop trigger if exists user_photos_url_change on public.user_photos;
create trigger user_photos_url_change
  before update of url on public.user_photos
  for each row execute function public.reset_face_focus_on_url_change();
