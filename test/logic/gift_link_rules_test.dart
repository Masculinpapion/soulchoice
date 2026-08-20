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

  group('normalizeGiftInput (20.08 paylaşım-metni vakası)', () {
    test('metin + tanınan link → yalnız link kalır', () {
      expect(
        normalizeGiftInput(
            'Духи — Золотое Яблоко https://goldapple.ru/19760282209-chance'),
        'https://goldapple.ru/19760282209-chance',
      );
      expect(
        normalizeGiftInput('Смотри что нашла!\nhttps://www.ozon.ru/product/1 🎁'),
        'https://www.ozon.ru/product/1',
      );
    });
    test('metin + tanınmayan link → dokunulmaz (doğrulama reddedecek)', () {
      const v = 'Кольцо https://avito.ru/item/1';
      expect(normalizeGiftInput(v), v);
    });
    test('saf link ve saf metin değişmez', () {
      expect(normalizeGiftInput(' https://goldapple.ru/x '),
          'https://goldapple.ru/x');
      expect(normalizeGiftInput('Красная помада'), 'Красная помада');
    });
  });

  group('giftTextForbiddenRe (sunucu 18.08 kümesiyle aynı)', () {
    test('yasak kalıplar yakalanır', () {
      for (final s in [
        'Парфюм 5000 ₽ переводом',
        'напиши в t.me/xx',
        'мой номер 8999',
        'скинь на карту',
        'пиши @handle',
        'см. www.site.ru',
      ]) {
        expect(giftTextForbiddenRe.hasMatch(s), isTrue, reason: s);
      }
    });
    test('normal ürün adları geçer', () {
      for (final s in [
        'Духи Chanel Chance',
        'Картхолдер кожаный', // "карта" kökü kelime içinde — yanlış pozitif olmamalı
        'Сертификатик' // ek almış hali sunucuda da serbest değil mi? [а-я]* ekiyle yakalanır
      ]) {
        // Сертификатик sunucu regex'inde de yakalanır (сертификат[а-я]*) —
        // istemci aynı davranmalı; ilk ikisi serbest.
        final expected = s.startsWith('Сертификат');
        expect(giftTextForbiddenRe.hasMatch(s), expected, reason: s);
      }
    });
  });
}
