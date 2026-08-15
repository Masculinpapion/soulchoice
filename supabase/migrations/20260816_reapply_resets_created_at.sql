-- 16.08.2026 — Mustafa bulgusu (S24): "en son başvurduğum davet Başvurularım'da
-- EN SONA düşüyor". Kök sebep: yeniden başvuru (withdrawn→pending, 24.07 kuralı)
-- istemcide UPSERT ile AYNI satırı güncelliyor; created_at ilk başvuru
-- tarihinde kalıyor → "yeniden eskiye" sıralama yalan söylüyor (Mustafa'nın
-- 3 pending kartının hepsi 29.07 damgalıydı — test envanteri davetleri geri
-- dönüştürdüğü için eski satırlar bugünkü davetlere yapışıyor).
-- Karar: yeniden başvuru = YENİ başvuru → created_at sıfırlanır; selected_at
-- temizlenir (responded_at'i enforce_application_rules zaten null'lar).
-- Dar kapsam bilinçli (11.08 deseni): enforce_application_rules'a dokunulmaz,
-- ayrı BEFORE UPDATE trigger; tüm roller için geçerli (service_role dahil —
-- semantik, güvenlik değil). Sahip tarafındaki kuyruk (created_at ASC) da
-- böylece adil: yeniden başvuran kuyruğun sonuna gider.
create or replace function public.reset_created_at_on_reapply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'withdrawn' and new.status = 'pending' then
    new.created_at := now();
    new.selected_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reset_created_at_on_reapply on public.applications;
create trigger trg_reset_created_at_on_reapply
  before update on public.applications
  for each row execute function public.reset_created_at_on_reapply();
