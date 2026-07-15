-- Hediye ürün linki — güvenli görünürlük (docs/product-logic.md §3.2).
-- MİMARİ: link, feed'de select edilen `invitations` tablosunda TUTULMAZ (kolon
-- olarak koyunca RLS aktif-ilan satırının tüm kolonlarını herkese açtığı için
-- `select=gift_product_url` ile yabancıya sızıyordu — E2E'de yakalandı). Bunun
-- yerine ayrı `invitation_gift_links` tablosu: doğrudan SELECT hiç kimseye açık
-- değil (RLS select policy yok); erişim yalnız iki SECURITY DEFINER RPC'den —
-- get_gift_link (seçilen kişi, match+approved) + get_own_gift_link (ilan sahibi).
-- Beyaz liste + moderasyon (pending→approved) trigger'da zorlanır.

begin;

-- Önceki (feed-sızıntılı) yaklaşımı geri al (idempotent — bu oturumda prod'a
-- uygulanmıştı, veri yok).
drop trigger if exists trg_enforce_gift_url on public.invitations;
drop function if exists public.enforce_gift_url();
drop function if exists public.get_gift_link(uuid);
drop function if exists public.get_own_gift_link(uuid);
alter table public.invitations drop column if exists gift_product_url;
alter table public.invitations drop column if exists gift_url_status;

create table if not exists public.invitation_gift_links (
  invitation_id uuid primary key references public.invitations(id) on delete cascade,
  url text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.invitation_gift_links enable row level security;

-- İlan sahibi kendi ilanının linkini yazar (insert/update/delete). SELECT policy
-- YOK → hiç kimse tabloyu doğrudan okuyamaz; okuma yalnız definer RPC'lerden.
drop policy if exists gift_link_owner_write on public.invitation_gift_links;
create policy gift_link_owner_write on public.invitation_gift_links for all
  using (invitation_id in (select id from public.invitations where owner_id = auth.uid()))
  with check (invitation_id in (select id from public.invitations where owner_id = auth.uid()));

-- Beyaz liste + kategori + moderasyon zorlaması. Link değişince daima 'pending'.
-- service_role (ops moderasyon) muaf → approve/reject yapabilir.
create or replace function public.enforce_gift_link()
returns trigger
language plpgsql
as $$
declare host text; inv_category text;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    new.updated_at := now();
    return new;
  end if;

  select category into inv_category from public.invitations where id = new.invitation_id;
  if inv_category is distinct from 'gift' then
    raise exception 'GIFT_URL_ONLY_FOR_GIFT_CATEGORY';
  end if;

  host := lower(regexp_replace(new.url, '^https?://([^/?#]+).*$', '\1'));
  host := regexp_replace(host, '^www\.', '');
  if host not in ('goldapple.ru','wildberries.ru','ozon.ru','market.yandex.ru','lamoda.ru','letoile.ru') then
    raise exception 'GIFT_URL_NOT_WHITELISTED';
  end if;

  -- kullanıcı yazınca daima moderasyona düşer (owner status'ü zorlayamaz)
  new.status := 'pending';
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_enforce_gift_link on public.invitation_gift_links;
create trigger trg_enforce_gift_link
  before insert or update on public.invitation_gift_links
  for each row execute function public.enforce_gift_link();

-- Seçilen kişi: yalnız match tarafı + moderasyon onaylı link
create or replace function public.get_gift_link(p_match_id uuid)
returns text
language sql
security definer
stable
as $$
  select l.url
  from public.invitation_gift_links l
  join public.matches m on m.invitation_id = l.invitation_id
  where m.id = p_match_id
    and (m.user1_id = auth.uid() or m.user2_id = auth.uid())
    and l.status = 'approved';
$$;

-- İlan sahibi: kendi linki + moderasyon durumu (create/edit ekranı)
create or replace function public.get_own_gift_link(p_invitation_id uuid)
returns table(url text, status text)
language sql
security definer
stable
as $$
  select l.url, l.status
  from public.invitation_gift_links l
  join public.invitations i on i.id = l.invitation_id
  where l.invitation_id = p_invitation_id
    and i.owner_id = auth.uid();
$$;

revoke all on function public.get_gift_link(uuid) from public;
revoke all on function public.get_own_gift_link(uuid) from public;
grant execute on function public.get_gift_link(uuid) to authenticated;
grant execute on function public.get_own_gift_link(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';
