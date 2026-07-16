import 'package:soulchoice/l10n/app_localizations.dart';

/// Preset selfie red sebebi slug'ını kullanıcının dilindeki metne çevirir.
/// Slug listesi panel (6 buton) + ops_reject_selfie + send-notification
/// SELFIE_REASONS ile senkron tutulur.
String? selfieReasonL10n(AppLocalizations l, String? slug) => switch (slug) {
      'face_unclear' => l.selfie_reason_face_unclear,
      'too_far' => l.selfie_reason_too_far,
      'accessories' => l.selfie_reason_accessories,
      'lighting' => l.selfie_reason_lighting,
      'mismatch' => l.selfie_reason_mismatch,
      'multiple_people' => l.selfie_reason_multiple_people,
      _ => null,
    };
