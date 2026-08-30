import 'package:soulchoice/l10n/app_localizations.dart';

/// Profil sorularının cevap kutuları için soru başına örnek metin (30.08,
/// Mustafa onayı) — genel «Твой ответ...» ilham vermiyordu; davet akışındaki
/// mekân örnekleri deseninin profile taşınması. Bilinmeyen anahtar eski
/// genel hint'e düşer. İki kullanıcı: onboarding sihirbazı + profil düzenleme.
String promptHintFor(AppLocalizations l, String key) {
  switch (key) {
    case 'favorite_restaurant':
      return l.profile_setup_prompt_hint_favorite_restaurant;
    case 'last_book':
      return l.profile_setup_prompt_hint_last_book;
    case 'perfect_evening':
      return l.profile_setup_prompt_hint_perfect_evening;
    case 'travel_dream':
      return l.profile_setup_prompt_hint_travel_dream;
    default:
      return l.profile_setup_prompts_answer_hint;
  }
}
