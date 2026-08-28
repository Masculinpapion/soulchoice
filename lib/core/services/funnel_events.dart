import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Kayıt hunisi telemetrisi (Katman 2, Mustafa onayı 28.08): kullanıcıların
/// akışın neresinde düştüğü AppMetrica'da görünür olsun (София selfie'de,
/// Гоша foto adımında bırakmıştı — o güne dek yalnız DB eşeleyerek
/// görülebiliyordu). Olaylar kişisel veri taşımaz; telemetri hatası ürün
/// akışını asla bozmaz.
void funnelEvent(String name, [Map<String, Object>? params]) {
  if (kIsWeb) return; // AppMetrica web demosunda aktive edilmiyor (01.08)
  try {
    if (params == null) {
      AppMetrica.reportEvent(name);
    } else {
      AppMetrica.reportEventWithMap(name, params);
    }
  } catch (_) {}
}

/// Cihaz başına tek sefer raporlanan olay (örn. first_apply).
Future<void> funnelEventOnce(String name) async {
  if (kIsWeb) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'funnel_once_$name';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    funnelEvent(name);
  } catch (_) {}
}
