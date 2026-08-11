import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nöbetçi Kovan faz 1 (12.08, Mustafa kararı): kullanıcının yaşadığı SESSİZ
/// hatalar (çökme değil — yakalanan hata/başarısız istek) sunucuya raporlanır.
/// Crashlytics'e dokunmaz, onun YANINA çalışır. Kurallar:
///  - asla kullanıcı deneyimini bozmaz (fire-and-forget, her hata yutulur)
///  - oturum başına en fazla 20 rapor; aynı hatanın tekrarı gönderilmez
///  - kişisel veri taşımaz (yalnız hata metni + ekran adı + build)
class ErrorReporter {
  ErrorReporter._();

  static String _build = '';
  static String? Function()? currentScreen;
  static int _sent = 0;
  static final Set<int> _seen = <int>{};

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _build = info.buildNumber;
    } catch (_) {}
  }

  static void report(Object error, {String? screen}) {
    try {
      final text = error.toString();
      final key =
          text.length > 120 ? text.substring(0, 120).hashCode : text.hashCode;
      if (_sent >= 20 || _seen.contains(key)) return;
      _seen.add(key);
      _sent++;

      String? uid;
      try {
        uid = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        return; // Supabase henüz ayakta değilse raporlama atlanır
      }

      unawaited(Supabase.instance.client.functions
          .invoke('log-client-error', body: {
            'user_id': uid,
            'platform': kIsWeb
                ? 'web'
                : Platform.isIOS
                    ? 'ios'
                    : 'android',
            'app_build': _build,
            'screen': screen ?? currentScreen?.call() ?? '',
            'error': text,
          })
          .timeout(const Duration(seconds: 8))
          .then((_) {}, onError: (_) {}));
    } catch (_) {
      // Telemetri asla uygulamayı bozmaz.
    }
  }
}
