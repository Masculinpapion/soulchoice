-- 11.08.2026 — Mustafa kararı: reddedilen/süresi dolan başvuru "geri çekilemez".
-- Açık: rejected→withdrawn (RLS izinliydi) → withdrawn→pending (24.07 kuralı)
-- zinciriyle reddedilen kullanıcı kendini aynı ilana YENİDEN sokabiliyordu.
-- İstemci butonu aynı gün kaldırıldı; bu trigger modifiye istemciyi de kapatır.
-- Dar kapsam bilinçli: enforce_application_rules'a dokunulmaz (guard-trigger
-- çakışma dersi, 07.2026) — yalnız bu iki geçiş engellenir, service_role muaf.
create or replace function public.block_withdraw_after_decision()
returns trigger
language plpgsql
security definer
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    return new;
  end if;
  if new.status = 'withdrawn' and old.status in ('rejected', 'expired') then
    raise exception 'INVALID_STATUS_TRANSITION';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_block_withdraw_after_decision on public.applications;
create trigger trg_block_withdraw_after_decision
  before update on public.applications
  for each row execute function public.block_withdraw_after_decision();
