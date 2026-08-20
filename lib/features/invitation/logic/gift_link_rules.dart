// Hediye (gift) ürün linki kuralları — TEK KAYNAK (create + edit + liste sayfası).
// DB tarafında aynı liste `enforce_gift_link` trigger'ında zorlanır
// (supabase/migrations/20260817_gift_whitelist_v2.sql) — burası yalnız erken/nazik UX.
//
// Kural (Mustafa 15.07 + 17.08):
// - Alan boş olabilir (opsiyonel).
// - http/https ile başlıyorsa LINK sayılır → yalnız tanınan mağazalar (alt alanlar
//   dahil: shop.mts.ru, m.ozon.ru, global.wildberries.ru …).
// - Link değilse SERBEST METİN (ürün adı/tarifi) — beyaz liste uygulanmaz.
// - Bilinçli DIŞARIDA: C2C pazarlar (Avito/Юла), sosyal-ağ mağazaları, kısaltılmış
//   linkler (clck.ru vb.), RU teslimatı olmayan yabancı siteler.

import 'package:soulchoice/l10n/app_localizations.dart';

/// Gruplu mağaza listesi — "Tanınan mağazalar" sayfası bu sırayla gösterir.
class GiftStoreGroup {
  final String key; // l10n anahtarı için: gift_stores_group_<key>
  final List<String> domains;
  const GiftStoreGroup(this.key, this.domains);

  String label(AppLocalizations l10n) => switch (key) {
        'marketplace' => l10n.gift_stores_group_marketplace,
        'beauty' => l10n.gift_stores_group_beauty,
        'fashion' => l10n.gift_stores_group_fashion,
        'electronics' => l10n.gift_stores_group_electronics,
        'telecom' => l10n.gift_stores_group_telecom,
        'jewelry' => l10n.gift_stores_group_jewelry,
        'books' => l10n.gift_stores_group_books,
        _ => l10n.gift_stores_group_home,
      };
}

const List<GiftStoreGroup> giftStoreGroups = [
  GiftStoreGroup('marketplace', [
    'ozon.ru', 'wildberries.ru', 'wb.ru', 'market.yandex.ru', 'megamarket.ru',
    'aliexpress.ru',
  ]),
  GiftStoreGroup('beauty', [
    'goldapple.ru', 'letoile.ru', 'rive-gauche.ru', 'podrygka.ru', 'randewoo.ru',
  ]),
  GiftStoreGroup('fashion', [
    'lamoda.ru', 'tsum.ru', 'brandshop.ru', 'sportmaster.ru', '12storeez.com',
    'befree.ru', 'lime-shop.com',
  ]),
  GiftStoreGroup('electronics', [
    'dns-shop.ru', 'mvideo.ru', 'eldorado.ru', 'citilink.ru', 're-store.ru',
    'technopark.ru', 'holodilnik.ru', 'onlinetrade.ru', 'samsung.com', 'mi.com',
  ]),
  GiftStoreGroup('telecom', [
    'mts.ru', 'megafon.ru', 'beeline.ru', 't2.ru', 'tele2.ru', 'svyaznoy.ru',
  ]),
  GiftStoreGroup('jewelry', [
    'sokolov.ru', 'sunlight.net', '585zolotoy.ru', 'adamas.ru', 'miuz.ru',
  ]),
  GiftStoreGroup('books', [
    'chitai-gorod.ru', 'labirint.ru', 'litres.ru', 'book24.ru',
  ]),
  GiftStoreGroup('home', [
    'detmir.ru', 'hoff.ru', 'flowwow.com',
  ]),
];

/// Düz küme (hızlı kontrol için).
final Set<String> giftStoreDomains = {
  for (final g in giftStoreGroups) ...g.domains,
};

final RegExp _linkRe = RegExp(r'^https?://', caseSensitive: false);

/// Girdi bir link mi (http/https)? Değilse serbest metin sayılır.
bool isGiftLink(String value) => _linkRe.hasMatch(value.trim());

final RegExp _embeddedLinkRe = RegExp(r'https?://\S+', caseSensitive: false);

/// Yapıştırılan içerikten kullanılabilir değeri çıkarır. Mağaza paylaşım
/// menüleri linki "Ürün adı https://goldapple.ru/…" biçiminde metinle birlikte
/// verir (20.08 Natalia vakası): metnin içinde tanınan mağazaya ait bir link
/// varsa YALNIZ o link kalır; yoksa metin olduğu gibi (trim) döner.
String normalizeGiftInput(String value) {
  final v = value.trim();
  if (v.isEmpty || isGiftLink(v)) return v;
  for (final m in _embeddedLinkRe.allMatches(v)) {
    final candidate = m.group(0)!;
    if (isWhitelistedGiftUrl(candidate)) return candidate;
  }
  return v;
}

/// Serbest metin dalında yasak kalıplar — sunucu `enforce_gift_link`
/// (18.08 antifraud) ile aynı küme: para/kart/СБП/sertifika/temas/link.
/// Sunucu otorite; burası erken ve anlaşılır UX.
final RegExp giftTextForbiddenRe = RegExp(
  r'(\d\s*(₽|руб|р\.))'
  r'|(?<![а-яёa-z])(карт[аеуы]|сбп|перевод[а-я]*|сертификат[а-я]*|номер|телефон[а-я]*|деньги|денег)(?![а-яёa-z])'
  r'|t\.me|wa\.me|@|https?:|www\.',
  caseSensitive: false,
);

/// Link tanınan mağazalardan birine mi ait? Alt alanlar dahil
/// (shop.mts.ru → mts.ru, m.ozon.ru → ozon.ru).
bool isWhitelistedGiftUrl(String url) {
  final m = RegExp(r'^https?://([^/?#]+)').firstMatch(url.trim().toLowerCase());
  if (m == null) return false;
  var host = m.group(1)!;
  final at = host.lastIndexOf('@'); // userinfo hilesi: user@evil.com
  if (at >= 0) host = host.substring(at + 1);
  host = host.split(':').first.replaceFirst(RegExp(r'^www\.'), '');
  for (final d in giftStoreDomains) {
    if (host == d || host.endsWith('.$d')) return true;
  }
  return false;
}

/// Alan doğrulaması: hata metni ya da null (geçerli/boş).
/// Girdi önce [normalizeGiftInput]'tan geçirilir — çağıran da SUNUCUYA
/// normalize edilmiş değeri göndermeli (aksi halde istemci geçirir, sunucu
/// reddeder — 20.08 vakası).
String? validateGiftField(String value, AppLocalizations l10n) {
  final v = normalizeGiftInput(value);
  if (v.isEmpty) return null;
  if (isGiftLink(v)) {
    return isWhitelistedGiftUrl(v) ? null : l10n.create_inv_gift_url_invalid;
  }
  if (v.length < 2 || v.length > 200) return l10n.create_inv_gift_url_invalid_text;
  if (giftTextForbiddenRe.hasMatch(v)) return l10n.create_inv_gift_text_forbidden;
  return null;
}
