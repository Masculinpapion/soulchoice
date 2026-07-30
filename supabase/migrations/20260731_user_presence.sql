-- Panel-only online gostergesi (31.07.2026): kullaniciya GORUNMEZ.
-- App on planda iken 2 dk'da bir touch_last_seen() cagirir; panel
-- last_seen_at > now()-5dk olanlari "online" sayar.
alter table public.users add column if not exists last_seen_at timestamptz;

create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update public.users set last_seen_at = now() where id = auth.uid();
$$;

revoke all on function public.touch_last_seen() from public;
grant execute on function public.touch_last_seen() to authenticated;

create index if not exists idx_users_last_seen_at
  on public.users (last_seen_at desc nulls last);
