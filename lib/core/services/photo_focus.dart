import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Yüz odaklı kadraj (akıllı kırpma).
///
/// Sunucudaki cron (ops/face_focus.py) her fotoğrafın yüz merkezini
/// user_photos.face_focus_x/y (0-1 fraksiyon) olarak yazar; -1 = yüz yok.
/// Bu harita oturum başına bir kez yüklenir; kart/avatar görünümleri
/// BoxFit.cover hizalamasını yüze göre seçer. Odak yoksa (yeni yükleme,
/// yüzsüz kare) çağıranın verdiği fallback kullanılır — zarif geri dönüş.
///
/// Not: Ölçek büyüyünce (on binlerce foto) bu tek-sorgu harita yerine odak
/// alanları mevcut join'lere taşınmalı; lansman ölçeğinde tek küçük sorgu.
class PhotoFocus {
  static final Map<String, Alignment> _byUrl = {};

  static Alignment of(String? url,
          {Alignment fallback = Alignment.topCenter}) =>
      (url == null ? null : _byUrl[url]) ?? fallback;

  static Future<void> load() async {
    final rows = await Supabase.instance.client
        .from('user_photos')
        .select('url, face_focus_x, face_focus_y')
        .gte('face_focus_x', 0);
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final fx = (r['face_focus_x'] as num).toDouble();
      final fy = (r['face_focus_y'] as num).toDouble();
      _byUrl[r['url'] as String] = Alignment(
        (fx * 2 - 1).clamp(-1.0, 1.0),
        (fy * 2 - 1).clamp(-1.0, 1.0),
      );
    }
  }
}

/// Ekranlar build başında watch eder; harita gelince rebuild tetiklenir.
final photoFocusProvider = FutureProvider<void>((ref) => PhotoFocus.load());
