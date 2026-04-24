// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get onboarding_1_title =>
      'План готов — не хватает только того, с кем пойти';

  @override
  String get onboarding_1_desc =>
      'Ресторан, концерт, выставка. Открой приглашение и угости — ты выбираешь, с кем пойдёшь.';

  @override
  String get onboarding_2_title =>
      'Скажи, куда хочешь пойти — и тебя пригласят';

  @override
  String get onboarding_2_desc =>
      'Coffeemania, Большой, концерт. Поделись желанием и жди того, кто угостит и сводит тебя туда.';

  @override
  String get onboarding_3_title => 'Проверенные профили, спокойное сообщество';

  @override
  String get onboarding_3_desc =>
      'Каждый пользователь подтверждается через селфи. Доверие — основа SoulChoice.';

  @override
  String get onboarding_start_button => 'Начать';

  @override
  String get onboarding_skip => 'Пропустить';

  @override
  String get nav_home => 'Главная';

  @override
  String get nav_discover => 'Обзор';

  @override
  String get nav_messages => 'Сообщения';

  @override
  String get nav_profile => 'Профиль';

  @override
  String get nav_notifications => 'Уведомления';

  @override
  String get btn_continue => 'Продолжить';

  @override
  String get btn_cancel => 'Отмена';

  @override
  String get btn_save => 'Сохранить';

  @override
  String get btn_delete => 'Удалить';

  @override
  String get btn_confirm => 'Подтвердить';

  @override
  String get btn_reject => 'Отклонить';

  @override
  String get btn_try_again => 'Повторить';

  @override
  String get empty_no_invitations => 'Пока нет активных приглашений';

  @override
  String get empty_no_messages => 'Пока нет сообщений';

  @override
  String get empty_no_notifications => 'Пока нет уведомлений';

  @override
  String get error_generic => 'Произошла ошибка';

  @override
  String get settings_language => 'Язык';

  @override
  String get settings_language_system => 'Язык системы';

  @override
  String get settings_notifications => 'Уведомления';

  @override
  String get settings_account => 'Аккаунт';

  @override
  String get settings_logout => 'Выйти';

  @override
  String get settings_delete_account => 'Удалить аккаунт';
}
