-- 17.08.2026 — Hediye ürün linki beyaz listesi v2 (Mustafa kararı):
--   * 6 → 46 tanınan mağaza (marketplace, kozmetik, moda, elektronik,
--     telekom salonları, takı, kitap, çocuk/ev/çiçek)
--   * ALT ALANLAR dahil: shop.mts.ru → mts.ru, m.ozon.ru → ozon.ru,
--     global.wildberries.ru → wildberries.ru (eskiden yalnız www. atılıyordu)
--   * userinfo hilesi (https://ozon.ru@evil.com/) ve port kırpılır
-- Serbest metin (ürün adı) kuralı ve status='pending' zorlaması AYNEN.
-- İstemci tarafı TEK KAYNAK: lib/features/invitation/logic/gift_link_rules.dart
-- (liste birebir aynı olmalı). Geri alma: 20260715_gift_link_or_text.sql fonksiyonu.

create or replace function public.enforce_gift_link()
returns trigger
language plpgsql
as $$
declare
  host text;
  inv_category text;
  d text;
  ok boolean := false;
  whitelist constant text[] := array[
    'ozon.ru',
    'wildberries.ru',
    'wb.ru',
    'market.yandex.ru',
    'megamarket.ru',
    'aliexpress.ru',
    'goldapple.ru',
    'letoile.ru',
    'rive-gauche.ru',
    'podrygka.ru',
    'randewoo.ru',
    'lamoda.ru',
    'tsum.ru',
    'brandshop.ru',
    'sportmaster.ru',
    '12storeez.com',
    'befree.ru',
    'lime-shop.com',
    'dns-shop.ru',
    'mvideo.ru',
    'eldorado.ru',
    'citilink.ru',
    're-store.ru',
    'technopark.ru',
    'holodilnik.ru',
    'onlinetrade.ru',
    'samsung.com',
    'mi.com',
    'mts.ru',
    'megafon.ru',
    'beeline.ru',
    't2.ru',
    'tele2.ru',
    'svyaznoy.ru',
    'sokolov.ru',
    'sunlight.net',
    '585zolotoy.ru',
    'adamas.ru',
    'miuz.ru',
    'chitai-gorod.ru',
    'labirint.ru',
    'litres.ru',
    'book24.ru',
    'detmir.ru',
    'hoff.ru',
    'flowwow.com'
  ];
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
    -- LINK: beyaz liste zorunlu (alt alanlar dahil)
    host := lower(regexp_replace(btrim(new.url), '^https?://([^/?#]+).*$', '\1'));
    host := regexp_replace(host, '^.*@', '');        -- userinfo hilesi
    host := regexp_replace(host, ':[0-9]+$', '');    -- port
    host := regexp_replace(host, '^www\.', '');
    foreach d in array whitelist loop
      if host = d or host like '%.' || d then
        ok := true;
        exit;
      end if;
    end loop;
    if not ok then
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
