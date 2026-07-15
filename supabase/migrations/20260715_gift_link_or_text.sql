-- Hediye ürün alanı artık link VEYA serbest metin kabul eder (Mustafa 15.07):
-- kullanıcı link aramak zorunda kalmasın, ürünü tarif de edebilsin. Link
-- (http/https) girilirse beyaz liste zorlanır; düz metin girilirse beyaz liste
-- atlanır (ürün adı/tarifi). İkisi de moderasyona (pending) düşer.
-- Kolon adı `url` korunur (içerik link ya da metin); app/chat isLink ile ayırır.

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

  if new.url ~* '^https?://' then
    -- LINK: beyaz liste zorunlu
    host := lower(regexp_replace(new.url, '^https?://([^/?#]+).*$', '\1'));
    host := regexp_replace(host, '^www\.', '');
    if host not in ('goldapple.ru','wildberries.ru','ozon.ru','market.yandex.ru','lamoda.ru','letoile.ru') then
      raise exception 'GIFT_URL_NOT_WHITELISTED';
    end if;
  else
    -- SERBEST METİN: ürün adı/tarifi (beyaz liste atlanır), makul uzunluk
    if length(btrim(new.url)) < 2 or length(new.url) > 200 then
      raise exception 'GIFT_TEXT_INVALID';
    end if;
  end if;

  new.status := 'pending';
  new.updated_at := now();
  return new;
end;
$$;
