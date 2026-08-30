import 'package:flutter_rustore_review/flutter_rustore_review.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/platform_x.dart';

const _kLastAskKey = 'review_last_ask_ms';
const _kAskCooldownMs = 90 * 24 * 60 * 60 * 1000; // 90 gün

/// Mağaza içi puanlama penceresi — yalnız mutlu anda çağrılır (buluşma
/// anketine "evet" cevabı). Sistemin resmi diyaloğu açılır, puan doğrudan
/// mağaza sayfasına gider; ön-filtre (memnuniyet sorusu) mağaza kurallarınca
/// yasak olduğundan yoktur.
///
/// Kurallar:
/// - 90 günde en fazla 1 istek (yerel sayaç; OS ayrıca kendi kotasını uygular,
///   örn. iOS yılda 3 — diyaloğun gerçekten görünme garantisi yoktur).
/// - Android'de önce RuStore denenir (vitrinimiz şu an orada canlı); RuStore
///   kurulu değilse/SDK hata verirse Play'e düşülür.
/// - Her hata sessiz yutulur — puan isteği hiçbir akışı bozamaz.
Future<void> maybeRequestReview() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastAskKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _kAskCooldownMs) return;

    var asked = false;
    if (isAndroidDevice) {
      try {
        await RustoreReviewClient.initialize();
        await RustoreReviewClient.request();
        await RustoreReviewClient.review();
        asked = true;
      } catch (_) {
        // RuStore yok/hazır değil — Play yoluna düş
      }
    }
    if (!asked) {
      final iar = InAppReview.instance;
      if (await iar.isAvailable()) {
        await iar.requestReview();
        asked = true;
      }
    }
    if (asked) await prefs.setInt(_kLastAskKey, now);
  } catch (_) {
    // Sessiz: puanlama isteği asla kullanıcı akışını bozmaz
  }
}
