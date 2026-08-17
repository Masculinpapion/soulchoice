// Hediye link beyaz listesi — istemci kuralı (DB trigger ile aynı liste).
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/features/invitation/logic/gift_link_rules.dart';

void main() {
  group('isWhitelistedGiftUrl', () {
    test('tanınan alan + alt alanlar kabul', () {
      for (final u in [
        'https://ozon.ru/product/1',
        'https://www.ozon.ru/product/1',
        'https://m.ozon.ru/product/1',
        'https://global.wildberries.ru/catalog/1',
        'https://shop.mts.ru/product/123',
        'https://market.yandex.ru/product--x/1',
        'HTTPS://GOLDAPPLE.RU/x',
        'https://ozon.ru:443/x',
      ]) {
        expect(isWhitelistedGiftUrl(u), isTrue, reason: u);
      }
    });
    test('tanınmayan / hileli alanlar ret', () {
      for (final u in [
        'https://www.avito.ru/item/1',
        'https://ozon.ru@evil.com/x',
        'https://notozon.ru/x',
        'https://ozon.ru.evil.com/x',
        'https://clck.ru/abc',
        'ftp://ozon.ru/x',
      ]) {
        expect(isWhitelistedGiftUrl(u), isFalse, reason: u);
      }
    });
    test('liste boş değil, tekrarsız ve küçük harf', () {
      expect(giftStoreDomains.length, greaterThanOrEqualTo(40));
      for (final d in giftStoreDomains) {
        expect(d, equals(d.toLowerCase()));
        expect(d.startsWith('www.'), isFalse);
      }
    });
  });
  test('isGiftLink', () {
    expect(isGiftLink('https://ozon.ru/x'), isTrue);
    expect(isGiftLink('  http://x.ru'), isTrue);
    expect(isGiftLink('Красная помада'), isFalse);
  });
}
