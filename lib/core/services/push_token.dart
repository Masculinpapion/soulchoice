import 'package:soulchoice/core/services/error_reporter.dart';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/platform_x.dart';

// Kullanıcının etkin dili (ayar > sistem) — push'lar alıcının dilinde gitsin
// diye users.locale'e yazılır; send-notification şablon seçiminde okur.
Future<String> _effectiveLocaleCode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('selected_locale');
  if (saved != null && saved != 'system') return saved;
  final sys = PlatformDispatcher.instance.locale.languageCode;
  return (sys == 'ru' || sys == 'tr') ? sys : 'en';
}

// 24.07 E2E: kayıt sırasında signedIn anında users satırı henüz yoktur (satır
// sihirbazın sonunda oluşur) — update 0 satıra denk gelir ve yeni kullanıcı
// yeniden açılışa kadar push alamaz. Bu yüzden kayıt/izin akışı bittiğinde de
// çağrılır (permissions_screen._finish).
/// 19.08 (senaryo denetimi): çıkış/askı-çıkışından ÖNCE çağrılır — aksi hâlde
/// aynı cihazda başka hesap girince önceki hesabın push'ları bu cihaza düşmeye
/// devam ediyordu (token kurulum başına sabit, users.fcm_token eski satırda kalıyordu).
/// Hata olursa yutulur; çıkış akışı engellenmez.
Future<void> clearPushTokenBeforeSignOut() async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      // rustore_token da temizlenir (28.08) — aynı cihaz-el-değiştirme
      // vakasının RuStore transportundaki karşılığı.
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': null, 'rustore_token': null})
          .eq('id', uid);
    }
    await FirebaseMessaging.instance.deleteToken();
  } catch (e, st) {
    ErrorReporter.report(e, stack: st, screen: 'push_token');
  }
  if (isAndroidDevice) {
    try {
      await RustorePushClient.deleteToken();
    } catch (_) {/* RuStore yoksa/SDK hata verirse çıkış engellenmez */}
  }
}

/// FCM birincil, RuStore ikincil kanal olarak TOKEN TOPLAR; sunucu
/// (send-notification) gönderimde FCM'i önceler, yoksa RuStore'a düşer.
/// 28.08 (София vakası): GMS'siz cihazda FCM getToken() hiç token veremiyor
/// ve eski yapıda tek try-catch tüm fonksiyonu düşürüyordu → kullanıcı
/// tamamen push'suz kalıyordu. Artık iki kanal bağımsız denenir.
Future<void> savePushToken() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;
  var saved = false;

  // Sürüm telemetrisi (28.08): RuStore'da güncelleme dağıtımı belirsiz —
  // hangi kullanıcının hangi build'de kaldığı ancak bu alanla görünür.
  int? appBuild;
  try {
    appBuild = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
  } catch (e, st) {
    ErrorReporter.report(e, stack: st, screen: 'push_token');
  }

  // 1) FCM — GMS'li Android + iOS
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await client.from('users').update({
        'fcm_token': token,
        'last_platform': platformTag,
        if (appBuild != null) 'app_build': appBuild,
      }).eq('id', uid);
      saved = true;
    }
  } catch (_) {/* GMS yok/erişilemez — RuStore yolu aşağıda denenir */}

  // 2) RuStore Push — yalnız Android; RuStore kurulu+oturumlu cihazlarda
  // token verir. FCM başarılı olsa da toplanır (cihaz envanteri + test).
  if (isAndroidDevice) {
    try {
      if (await RustorePushClient.available()) {
        final rt = await RustorePushClient.getToken();
        if (rt.isNotEmpty) {
          await client.from('users').update({
            'rustore_token': rt,
            if (!saved) 'last_platform': platformTag,
            if (!saved && appBuild != null) 'app_build': appBuild,
          }).eq('id', uid);
          saved = true;
        }
      }
    } catch (_) {/* RuStore yok/SDK hatası — sessiz, FCM durumu değişmez */}
  }

  if (!saved) return;
  // locale burada EZİLMEZ (16.07: cihaz, hesabın dilini eziyordu);
  // yalnız hesapta hiç dil yoksa (yeni kayıt) etkin dil doldurulur.
  try {
    await client
        .from('users')
        .update({'locale': await _effectiveLocaleCode()})
        .eq('id', uid)
        .isFilter('locale', null);
  } catch (e, st) {
    ErrorReporter.report(e, stack: st, screen: 'push_token');
  }
}
