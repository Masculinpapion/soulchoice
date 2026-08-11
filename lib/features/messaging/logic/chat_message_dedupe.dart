/// Sohbet realtime INSERT dedupe kuralı — SAF mantık.
/// 11.08 hata sınıfı: reconnect'te kanal rejoin + tam reload yarışınca aynı
/// mesaj listeye İKİ kez ekleniyordu. Kural: gelen realtime mesajı listeye
/// yalnız (1) başkasından geldiyse (kendi mesajım optimistic yolla zaten
/// eklendi) ve (2) aynı id listede YOKSA eklenir.
/// chat_screen.dart realtime callback'i buradan çağırır; test:
/// test/logic/chat_message_dedupe_test.dart.
library;

bool shouldAppendRealtimeMessage({
  required String? currentUid,
  required String? senderId,
  required String messageId,
  required Iterable<String> existingIds,
}) {
  // Kendi mesajım: gönderim anında optimistic olarak eklendi; realtime
  // yankısı eklenmez. (== karşılaştırması eski koddaki `senderId != _currentUid`
  // koşuluyla birebir aynı — null/null dahil davranış değişikliği yok.)
  if (senderId == currentUid) return false;
  return !existingIds.contains(messageId);
}
