import 'package:flutter/services.dart';

/// Sistem bildirim çekmecesi temizliği (31.07).
///
/// Sohbet/başvuranlar ekranı uygulama İÇİNDEN açıldığında o kaydın çekmecede
/// bayat duran bildirimi kaldırılır; iOS rozet sayısı uygulama öne gelince
/// sıfırlanır. Hepsi best-effort — platform kanalı yoksa sessizce geçer,
/// akışı asla bozmaz. Anahtar biçimi sunucuyla sözleşmeli: "<tip>:<ref>"
/// (send-notification collapse key'i ile birebir aynı).
class NotificationCleaner {
  NotificationCleaner._();
  static const _ch = MethodChannel('com.soulchoice/notifications');

  static Future<void> clearForChat(String matchId) async {
    if (matchId.isEmpty) return;
    for (final t in ['new_message', 'selected', 'match']) {
      try {
        await _ch.invokeMethod('clearByKey', '$t:$matchId');
      } catch (_) {/* süs özellik — hata yutulur */}
    }
  }

  static Future<void> clearForInvitation(String invitationId) async {
    if (invitationId.isEmpty) return;
    for (final t in ['new_application', 'selection_reminder']) {
      try {
        await _ch.invokeMethod('clearByKey', '$t:$invitationId');
      } catch (_) {/* süs özellik — hata yutulur */}
    }
  }

  static Future<void> clearBadge() async {
    try {
      await _ch.invokeMethod('clearBadge');
    } catch (_) {/* süs özellik — hata yutulur */}
  }
}
