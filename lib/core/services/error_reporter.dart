import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nöbetçi Kovan faz 1 (12.08, Mustafa kararı): kullanıcının yaşadığı SESSİZ
/// hatalar (çökme değil — yakalanan hata/başarısız istek) sunucuya raporlanır.
/// Crashlytics'e dokunmaz, onun YANINA çalışır. Kurallar:
///  - asla kullanıcı deneyimini bozmaz (fire-and-forget, her hata yutulur)
///  - oturum başına en fazla 20 rapor; aynı hatanın tekrarı gönderilmez
///  - kişisel veri taşımaz (hata metni + ekran + build + cihaz OS sürümü)
///
/// 03.09 (kalite teşhisi): stack trace (ilk 4000 kr), gerçek rota (router
/// izleyici), cihaz OS bilgisi ve ÇEVRİMDIŞI KUYRUK (gönderilemeyen rapor
/// SharedPreferences'ta bekler, bir sonraki açılışta/bağlantıda gider) —
/// eskiden çevrimdışı/açılış hataları kalıcı olarak kayboluyordu.
class ErrorReporter {
  ErrorReporter._();

  static String _build = '';
  static String? Function()? currentScreen;
  static int _sent = 0;
  static final Set<int> _seen = <int>{};
  static bool _ready = false;
  static const _queueKey = 'error_reporter_queue_v1';
  static const _queueMax = 20;

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _build = info.buildNumber;
    } catch (_) {}
    _ready = true;
    unawaited(flushQueue());
  }

  static void report(Object error, {StackTrace? stack, String? screen}) {
    try {
      final text = error.toString();
      final key =
          text.length > 120 ? text.substring(0, 120).hashCode : text.hashCode;
      if (_sent >= 20 || _seen.contains(key)) return;
      _seen.add(key);
      _sent++;
      final payload = _payload(text, stack, screen);
      unawaited(_send(payload).then((ok) {
        if (!ok) unawaited(_enqueue(payload));
      }));
    } catch (_) {
      // Telemetri asla uygulamayı bozmaz.
    }
  }

  static Map<String, dynamic> _payload(
      String text, StackTrace? stack, String? screen) {
    String? uid;
    try {
      uid = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
    String device = '';
    try {
      device = kIsWeb
          ? 'web'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {}
    String? st;
    if (stack != null) {
      final s = stack.toString();
      st = s.length > 4000 ? s.substring(0, 4000) : s;
    }
    return {
      'user_id': uid,
      'platform': kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : 'android',
      'app_build': _build,
      'screen': screen ?? currentScreen?.call() ?? '',
      'error': text,
      if (st != null) 'stack': st,
      'device': device,
    };
  }

  static Future<bool> _send(Map<String, dynamic> payload) async {
    if (!_ready) return false;
    try {
      await Supabase.instance.client.functions
          .invoke('log-client-error', body: payload)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _enqueue(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_queueKey) ?? <String>[];
      if (list.length >= _queueMax) list.removeAt(0);
      list.add(jsonEncode(payload));
      await prefs.setStringList(_queueKey, list);
    } catch (_) {}
  }

  /// Bekleyen raporları gönderir (açılışta ve bağlantı dönünce çağrılabilir).
  static Future<void> flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_queueKey) ?? <String>[];
      if (list.isEmpty) return;
      final remaining = <String>[];
      for (final item in list) {
        final ok = await _send(
            (jsonDecode(item) as Map).cast<String, dynamic>());
        if (!ok) remaining.add(item);
      }
      await prefs.setStringList(_queueKey, remaining);
    } catch (_) {}
  }
}
