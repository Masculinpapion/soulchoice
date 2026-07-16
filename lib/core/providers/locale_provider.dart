import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

Locale _fromSystem() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  if (code == 'ru') return const Locale('ru');
  if (code == 'tr') return const Locale('tr');
  return const Locale('en');
}

class LocaleNotifier extends StateNotifier<Locale?> {
  static const _key = 'selected_locale';

  LocaleNotifier() : super(null) {
    _loadSavedLocale();
    // KURAL (16.07): dilin sahibi HESAPTIR, cihaz tercihi önbellektir.
    // Girişte hesabın dili cihaza uygulanır; çıkışta cihaz 'system'e döner
    // (aynı cihazda önceki kullanıcının dili yeni hesaba sızıyordu).
    Supabase.instance.client.auth.onAuthStateChange.listen((e) {
      switch (e.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          _adoptFromAccount();
        case AuthChangeEvent.signedOut:
          _resetToSystem();
        default:
          break;
      }
    });
  }

  /// Hesabın dilini cihaza uygular. 'Sistem dili' modunda arayüz sisteme
  /// bağlı kalır, yalnız etkin dil hesaba yazılır (push dili = görünen dil).
  Future<void> _adoptFromAccount() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'system') {
        _syncToDb((state ?? _fromSystem()).languageCode);
        return;
      }
      final row = await Supabase.instance.client
          .from('users')
          .select('locale')
          .eq('id', uid)
          .maybeSingle();
      final dbLocale = row?['locale'] as String?;
      if (dbLocale != null && const {'ru', 'tr', 'en'}.contains(dbLocale)) {
        state = Locale(dbLocale);
        await prefs.setString(_key, dbLocale);
      } else {
        // Hesapta dil yok (yeni kayıt) — etkin dili hesaba yaz
        _syncToDb((state ?? _fromSystem()).languageCode);
      }
    } catch (_) {
      // Çevrimdışı vb. — cihazdaki tercih geçerli kalır
    }
  }

  Future<void> _resetToSystem() async {
    state = _fromSystem();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'system');
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved == 'system') {
      state = _fromSystem();
    } else {
      state = Locale(saved);
    }
  }

  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
    _syncToDb(languageCode);
  }

  Future<void> useSystemLocale() async {
    state = _fromSystem();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'system');
    _syncToDb(state!.languageCode);
  }

  // Push'lar alıcının dilinde gitsin — dil değişince sunucuya da yaz
  void _syncToDb(String code) {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      Supabase.instance.client
          .from('users')
          .update({'locale': code})
          .eq('id', uid)
          .then((_) {}, onError: (_) {});
    } catch (_) {}
  }
}
