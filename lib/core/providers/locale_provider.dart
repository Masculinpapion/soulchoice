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
