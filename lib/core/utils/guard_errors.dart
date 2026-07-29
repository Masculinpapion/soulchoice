import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

/// Sunucu guard trigger'larının token hatalarını (SELFIE_NOT_APPROVED vb.)
/// lokalize mesaja + doğru yönlendirmeye çevirir. Ham `e.toString()` snackbar'ı
/// yasak — Kullanıcı Kapısı §13.1/6.
class GuardError {
  final String message;

  /// Mesajı gösterdikten sonra kullanıcıyı götürülecek rota (null = kalınır).
  final String? route;

  const GuardError(this.message, [this.route]);

  /// Bilinen guard token'ı değilse null döner — çağıran genel hata yolunu izler.
  static GuardError? from(BuildContext context, Object e) {
    final l10n = AppLocalizations.of(context)!;
    final s = e.toString();
    if (s.contains('SELFIE_NOT_APPROVED')) {
      return GuardError(l10n.err_selfie_required, '/profile/selfie');
    }
    if (s.contains('APPLY_LIMIT_REACHED')) {
      return GuardError(l10n.err_apply_limit, '/paywall');
    }
    if (s.contains('INVITATION_NOT_OPEN')) {
      return GuardError(l10n.err_invitation_closed);
    }
    if (s.contains('ACTIVE_INVITATION_LIMIT')) {
      return GuardError(l10n.err_active_invitation_limit);
    }
    if (s.contains('ACCOUNT_SUSPENDED')) {
      return GuardError(l10n.err_account_suspended, '/suspended');
    }
    return null;
  }

  /// Sunucu guard'ı pending/none/rejected ayırmadan tek SELFIE_NOT_APPROVED
  /// token'ı atar. Onay bekleyen kullanıcı kameraya değil bekleme mesajına
  /// düşmeli (yönlendirme yok) — durum burada istemciden okunur.
  static Future<GuardError?> resolve(BuildContext context, Object e) async {
    final base = from(context, e);
    if (base == null || base.route != '/profile/selfie') return base;
    final pendingMessage = AppLocalizations.of(context)!.err_selfie_pending;
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return base;
      final row = await client
          .from('users')
          .select('selfie_status')
          .eq('id', uid)
          .maybeSingle();
      if (row?['selfie_status'] == 'pending') {
        return GuardError(pendingMessage);
      }
    } catch (_) {
      // Durum okunamazsa mevcut davranış korunur.
    }
    return base;
  }

  void navigate(BuildContext context) {
    final r = route;
    if (r == null) return;
    if (r == '/suspended') {
      context.go(r);
    } else {
      context.push(r);
    }
  }
}
