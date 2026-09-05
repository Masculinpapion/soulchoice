// Feed delta sayfalama imleci — 05.09. Sıralama sözleşmesi
// (feed_rank ASC, created_at DESC, id ASC) invitations_provider ile birebir;
// sıralama değişirse ÖNCE provider, sonra feed_keyset.dart, sonra bu test.
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/features/feed/logic/feed_keyset.dart';

void main() {
  const row = <String, dynamic>{
    'id': '0c3e4b0e-9f1a-4c2b-8f6d-1a2b3c4d5e6f',
    'feed_rank': 1,
    'created_at': '2026-09-05T12:34:56.789012+00:00',
    'status': 'active',
  };

  group('feedCursorFromRow', () {
    test('tam satır → imleç üç alanı aynen taşır', () {
      final c = feedCursorFromRow(row);
      expect(c, isNotNull);
      expect(c!.feedRank, 1);
      expect(c.createdAt, '2026-09-05T12:34:56.789012+00:00');
      expect(c.id, '0c3e4b0e-9f1a-4c2b-8f6d-1a2b3c4d5e6f');
    });

    test('created_at eksik/boş veya feed_rank tipsiz → null (devamı yok)', () {
      expect(feedCursorFromRow({...row}..remove('created_at')), isNull);
      expect(feedCursorFromRow({...row, 'created_at': ''}), isNull);
      expect(feedCursorFromRow({...row, 'feed_rank': '1'}), isNull);
      expect(feedCursorFromRow({...row, 'id': null}), isNull);
    });
  });

  group('feedKeysetAfter', () {
    test('rank ASC / created_at DESC / id ASC üçlü koşul, değerler tırnaklı', () {
      final expr = feedKeysetAfter(feedCursorFromRow(row)!);
      expect(
        expr,
        'feed_rank.gt.1,'
        'and(feed_rank.eq.1,created_at.lt."2026-09-05T12:34:56.789012+00:00"),'
        'and(feed_rank.eq.1,created_at.eq."2026-09-05T12:34:56.789012+00:00",'
        'id.gt."0c3e4b0e-9f1a-4c2b-8f6d-1a2b3c4d5e6f")',
      );
    });

    test('created_at DESC: aynı rank içinde «sonrası» = daha ESKİ (lt)', () {
      final expr = feedKeysetAfter(
          (feedRank: 0, createdAt: '2026-01-01T00:00:00+00:00', id: 'x'));
      expect(expr, contains('created_at.lt."2026-01-01T00:00:00+00:00"'));
      expect(expr, isNot(contains('created_at.gt.')));
    });
  });
}
