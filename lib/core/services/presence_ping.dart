import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel-only online sinyali (31.07.2026).
///
/// Uygulama ÖN PLANDAYKEN ve oturum varken 2 dakikada bir sessizce
/// `touch_last_seen()` RPC'sini çağırır — kullanıcıya hiçbir yüzeyde
/// GÖSTERİLMEZ, yalnız ops paneli okur. Hata yutulur: sinyal süsleyicidir,
/// akışı asla bozamaz.
class PresencePing with WidgetsBindingObserver {
  PresencePing._();
  static final PresencePing instance = PresencePing._();

  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resume() {
    _ping();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      await Supabase.instance.client.rpc('touch_last_seen');
    } catch (_) {
      // Sessiz: çevrimdışı/aralıklı ağda gürültü üretme.
    }
  }
}
