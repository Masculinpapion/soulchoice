-- 20.08.2026 (Mustafa kararı): hediye linki moderasyonu hızlandırma.
-- Beyaz listedeki mağazaya giden https linki trigger'da OTOMATİK ONAYLANIR
-- (domain zaten doğrulanıyor; insan onayı beklemek akışı geciktiriyordu).
-- Serbest metin (ürün adı) MANUEL moderasyonda kalır — para/temas regex'i var
-- ama yaratıcı dolandırıcılık metni insan gözü ister; kuyruk Telegram'a bildirilir
-- (monitoring/checks.sh). Önceki tanım:
--   /root/backups/fn_enforce_gift_link_pre_autoapprove_20260820.sql

create or replace function public.enforce_gift_link()
returns trigger language plpgsql as $$
declare
  host text;
  inv_category text;
  d text;
  ok boolean := false;
  whitelist constant text[] := array[
    'ozon.ru','wildberries.ru','wb.ru','market.yandex.ru','megamarket.ru','aliexpress.ru',
    'goldapple.ru','letoile.ru','rive-gauche.ru','podrygka.ru','randewoo.ru',
    'lamoda.ru','tsum.ru','brandshop.ru','sportmaster.ru','12storeez.com','befree.ru','lime-shop.com',
    'dns-shop.ru','mvideo.ru','eldorado.ru','citilink.ru','re-store.ru','technopark.ru','holodilnik.ru','onlinetrade.ru',
    'samsung.com','mi.com','mts.ru','megafon.ru','beeline.ru','t2.ru','tele2.ru','svyaznoy.ru',
    'sokolov.ru','sunlight.net','585zolotoy.ru','adamas.ru','miuz.ru',
    'chitai-gorod.ru','labirint.ru','litres.ru','book24.ru','detmir.ru','hoff.ru','flowwow.com'
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
    -- 20.08: tanınan mağaza linki insan onayı beklemez
    new.status := 'approved';
  else
    -- SERBEST METİN: ürün adı/tarifi (beyaz liste atlanır), makul uzunluk
    if length(btrim(new.url)) < 2 or length(new.url) > 200 then
      raise exception 'GIFT_TEXT_INVALID';
    end if;
    -- 18.08: metin dalında para/kart/СБП/sertifika/temas isteği yasak (yalnız ürün adı)
    if new.url ~* '(\d\s*(₽|руб|р\.)|\y(карт[аеуы]|сбп|перевод[а-я]*|сертификат[а-я]*|номер|телефон[а-я]*|деньги|денег)\y|t\.me|wa\.me|@|https?:|www\.)' then
      raise exception 'GIFT_TEXT_FORBIDDEN';
    end if;
    -- metin dalı manuel moderasyonda kalır
    new.status := 'pending';
  end if;

  new.updated_at := now();
  return new;
end $$;
