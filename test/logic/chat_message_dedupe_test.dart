// Sohbet realtime dedupe kural testleri — 11.08 hata sınıfı: reconnect'te
// kanal rejoin + tam reload yarışınca aynı mesaj listeye iki kez düşüyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/features/messaging/logic/chat_message_dedupe.dart';

void main() {
  const me = 'uid-me';
  const partner = 'uid-partner';

  group('shouldAppendRealtimeMessage', () {
    test('karşı taraftan yeni id → EKLENİR', () {
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: partner,
          messageId: 'm2',
          existingIds: ['m1'],
        ),
        isTrue,
      );
    });

    test('aynı id listede varsa İKİNCİ kez EKLENMEZ (reconnect yarışı)', () {
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: partner,
          messageId: 'm1',
          existingIds: ['m1', 'm2'],
        ),
        isFalse,
      );
    });

    test('kendi mesajımın realtime yankısı EKLENMEZ (optimistic zaten ekledi)',
        () {
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: me,
          messageId: 'm3',
          existingIds: ['m1'],
        ),
        isFalse,
      );
    });

    test('silinmiş kullanıcı mesajı (senderId null) karşı taraf sayılır — '
        'yeni id eklenir, tekrar eklenmez', () {
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: null,
          messageId: 'm4',
          existingIds: ['m1'],
        ),
        isTrue,
      );
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: null,
          messageId: 'm4',
          existingIds: ['m1', 'm4'],
        ),
        isFalse,
      );
    });

    test('boş listeye ilk mesaj eklenir', () {
      expect(
        shouldAppendRealtimeMessage(
          currentUid: me,
          senderId: partner,
          messageId: 'm1',
          existingIds: const [],
        ),
        isTrue,
      );
    });
  });
}
