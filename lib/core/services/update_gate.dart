import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sunucudan yönetilen zorunlu-güncelleme kapısı (28.08).
///
/// RuStore'da güncelleme dağıtımı yavaş/belirsiz (São 768 çıktıktan sonra da
/// 708'de kaldı) ve her sürüm ≤3 gün moderasyona takılıyor — kritik bir fix'te
/// eski sürümleri ancak bu kapı durdurabilir. `feature_flags.min_supported_build`
/// ({"v": N}) mevcut build'den büyükse uygulama /update-required'a kilitlenir.
/// Bayrak 0/yok/okunamıyor (çevrimdışı dahil) → KAPI YOK, normal açılış —
/// kapı asla yanlış pozitifle kullanıcıyı dışarıda bırakmaz.
class UpdateGate {
  UpdateGate._();

  static Future<bool> updateRequired() async {
    if (kIsWeb) return false;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      if (build == 0) return false;
      final flag = await Supabase.instance.client
          .from('feature_flags')
          .select('value')
          .eq('key', 'min_supported_build')
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final v = (flag?['value'] as Map?)?['v'];
      final min = v is int ? v : int.tryParse('$v') ?? 0;
      return min > 0 && build < min;
    } catch (_) {
      return false;
    }
  }
}
