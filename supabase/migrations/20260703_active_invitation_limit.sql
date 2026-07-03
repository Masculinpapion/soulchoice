-- ─────────────────────────────────────────────────────────────────────────────
-- Aktif davetiye/istek sınırı — kullanıcı başına flow_type'ta en fazla 1 aktif
-- Not: invitations.status süresi dolunca otomatik değişmiyor (cron yok),
-- sadece expires_at ile filtreleniyor. Bu yüzden partial unique index (now()
-- immutable olmadığı için) kullanılamaz — trigger ile kontrol ediliyor.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function check_active_invitation_limit()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active' and exists (
    select 1 from invitations
    where owner_id = new.owner_id
      and flow_type = new.flow_type
      and status = 'active'
      and expires_at > now()
      and id != new.id
  ) then
    raise exception 'ACTIVE_INVITATION_LIMIT'
      using detail = new.flow_type;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_active_invitation_limit on invitations;
create trigger trg_check_active_invitation_limit
before insert or update on invitations
for each row
execute function check_active_invitation_limit();
