import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
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
