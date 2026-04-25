import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ru'),
    Locale('tr'),
  ];

  /// No description provided for @onboarding_1_title.
  ///
  /// In tr, this message translates to:
  /// **'Planın hazır, eksik olan birlikte gidecek biri'**
  String get onboarding_1_title;

  /// No description provided for @onboarding_1_desc.
  ///
  /// In tr, this message translates to:
  /// **'Bir restoran, bir konser, bir etkinlik. Davet aç, ısmarla ve kiminle gitmek istediğini sen seç.'**
  String get onboarding_1_desc;

  /// No description provided for @onboarding_2_title.
  ///
  /// In tr, this message translates to:
  /// **'Gitmek istediğin yeri söyle, biri seni davet etsin'**
  String get onboarding_2_title;

  /// No description provided for @onboarding_2_desc.
  ///
  /// In tr, this message translates to:
  /// **'Bir kafe, bir tiyatro, bir konser. İsteğini paylaş, ısmarlayıp seni götürecek birini bekle.'**
  String get onboarding_2_desc;

  /// No description provided for @onboarding_3_title.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulanmış profiller, sorumlu bir topluluk'**
  String get onboarding_3_title;

  /// No description provided for @onboarding_3_desc.
  ///
  /// In tr, this message translates to:
  /// **'Her profil selfie ile onaylanır. Randevuya gelmeyen veya uygunsuz davranan kullanıcılar engellenir.'**
  String get onboarding_3_desc;

  /// No description provided for @onboarding_start_button.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get onboarding_start_button;

  /// No description provided for @onboarding_skip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get onboarding_skip;

  /// No description provided for @nav_home.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get nav_home;

  /// No description provided for @nav_discover.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get nav_discover;

  /// No description provided for @nav_messages.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get nav_messages;

  /// No description provided for @nav_profile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get nav_profile;

  /// No description provided for @nav_notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get nav_notifications;

  /// No description provided for @btn_continue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get btn_continue;

  /// No description provided for @btn_cancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get btn_cancel;

  /// No description provided for @btn_save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get btn_save;

  /// No description provided for @btn_delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get btn_delete;

  /// No description provided for @btn_confirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get btn_confirm;

  /// No description provided for @btn_reject.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get btn_reject;

  /// No description provided for @btn_try_again.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get btn_try_again;

  /// No description provided for @empty_no_invitations.
  ///
  /// In tr, this message translates to:
  /// **'Henüz aktif davet yok'**
  String get empty_no_invitations;

  /// No description provided for @empty_no_messages.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesajın yok'**
  String get empty_no_messages;

  /// No description provided for @empty_no_notifications.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildirimin yok'**
  String get empty_no_notifications;

  /// No description provided for @error_generic.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu'**
  String get error_generic;

  /// No description provided for @settings_language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get settings_language;

  /// No description provided for @settings_language_system.
  ///
  /// In tr, this message translates to:
  /// **'Sistem dili'**
  String get settings_language_system;

  /// No description provided for @settings_notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get settings_notifications;

  /// No description provided for @settings_account.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get settings_account;

  /// No description provided for @settings_logout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get settings_logout;

  /// No description provided for @settings_delete_account.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı sil'**
  String get settings_delete_account;

  String get settings_title;
  String get settings_profile_section;
  String get settings_edit_profile;
  String get settings_edit_photos;
  String get settings_notification_prefs;
  String get settings_do_not_disturb;
  String get settings_active_devices;
  String get settings_download_data;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
