import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
Future<void> savePushToken() async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client
        .from('users')
        .update({
          'fcm_token': token,
          'last_platform': Platform.isIOS ? 'ios' : 'android',
        })
        .eq('id', uid);
    // locale burada EZİLMEZ (16.07: cihaz, hesabın dilini eziyordu);
    // yalnız hesapta hiç dil yoksa (yeni kayıt) etkin dil doldurulur.
    await Supabase.instance.client
        .from('users')
        .update({'locale': await _effectiveLocaleCode()})
        .eq('id', uid)
        .isFilter('locale', null);
  } catch (_) {}
}
