import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
    Locale('en'),
    Locale('ru'),
    Locale('tr'),
  ];

  /// No description provided for @onboarding_1_title.
  ///
  /// In en, this message translates to:
  /// **'You have the plan. Now find someone to go with.'**
  String get onboarding_1_title;

  /// No description provided for @onboarding_1_desc.
  ///
  /// In en, this message translates to:
  /// **'A restaurant, a concert, an event. Open an invitation, treat and choose who comes along.'**
  String get onboarding_1_desc;

  /// No description provided for @onboarding_2_title.
  ///
  /// In en, this message translates to:
  /// **'Say where you want to go, let someone invite you'**
  String get onboarding_2_title;

  /// No description provided for @onboarding_2_desc.
  ///
  /// In en, this message translates to:
  /// **'A café, a theatre, a concert. Share your wish and wait for someone to treat and take you.'**
  String get onboarding_2_desc;

  /// No description provided for @onboarding_3_title.
  ///
  /// In en, this message translates to:
  /// **'Verified profiles, a responsible community'**
  String get onboarding_3_title;

  /// No description provided for @onboarding_3_desc.
  ///
  /// In en, this message translates to:
  /// **'Every profile is verified with a selfie. Users who miss meetings or behave inappropriately are blocked.'**
  String get onboarding_3_desc;

  /// No description provided for @onboarding_start_button.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboarding_start_button;

  /// No description provided for @onboarding_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboarding_skip;

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @nav_discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get nav_discover;

  /// No description provided for @nav_messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get nav_messages;

  /// No description provided for @nav_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// No description provided for @nav_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get nav_notifications;

  /// No description provided for @btn_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btn_continue;

  /// No description provided for @btn_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btn_cancel;

  /// No description provided for @btn_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btn_save;

  /// No description provided for @btn_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btn_delete;

  /// No description provided for @btn_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get btn_confirm;

  /// No description provided for @btn_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get btn_reject;

  /// No description provided for @btn_try_again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get btn_try_again;

  /// No description provided for @empty_no_invitations.
  ///
  /// In en, this message translates to:
  /// **'No active invitations yet'**
  String get empty_no_invitations;

  /// No description provided for @empty_no_messages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get empty_no_messages;

  /// No description provided for @empty_no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get empty_no_notifications;

  /// No description provided for @error_generic.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error_generic;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_language_system.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get settings_language_system;

  /// No description provided for @settings_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_notifications;

  /// No description provided for @settings_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_account;

  /// No description provided for @settings_logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settings_logout;

  /// No description provided for @settings_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settings_delete_account;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_profile_section.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settings_profile_section;

  /// No description provided for @settings_edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settings_edit_profile;

  /// No description provided for @settings_edit_photos.
  ///
  /// In en, this message translates to:
  /// **'Edit photos'**
  String get settings_edit_photos;

  /// No description provided for @settings_notification_prefs.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get settings_notification_prefs;

  /// No description provided for @settings_do_not_disturb.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get settings_do_not_disturb;

  /// No description provided for @settings_active_devices.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get settings_active_devices;

  /// No description provided for @settings_download_data.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get settings_download_data;

  /// No description provided for @phone_title.
  ///
  /// In en, this message translates to:
  /// **'Enter your\nphone number'**
  String get phone_title;

  /// No description provided for @phone_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We will send you a verification code'**
  String get phone_subtitle;

  /// No description provided for @phone_error_empty.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get phone_error_empty;

  /// No description provided for @phone_error_connection.
  ///
  /// In en, this message translates to:
  /// **'Connection error, please try again'**
  String get phone_error_connection;

  /// No description provided for @phone_terms.
  ///
  /// In en, this message translates to:
  /// **'By continuing you accept the Terms of Use'**
  String get phone_terms;

  /// No description provided for @otp_title.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otp_title;

  /// No description provided for @otp_sent_to.
  ///
  /// In en, this message translates to:
  /// **'Sent to: '**
  String get otp_sent_to;

  /// No description provided for @otp_resend_countdown.
  ///
  /// In en, this message translates to:
  /// **'Resend ({seconds}s)'**
  String otp_resend_countdown(int seconds);

  /// No description provided for @otp_resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get otp_resend;

  /// No description provided for @otp_verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otp_verify;

  /// No description provided for @otp_error_failed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get otp_error_failed;

  /// No description provided for @perm_notification_title.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get perm_notification_title;

  /// No description provided for @perm_notification_desc.
  ///
  /// In en, this message translates to:
  /// **'Required to notify you of new messages when selected'**
  String get perm_notification_desc;

  /// No description provided for @perm_location_title.
  ///
  /// In en, this message translates to:
  /// **'Share your location'**
  String get perm_location_title;

  /// No description provided for @perm_location_desc.
  ///
  /// In en, this message translates to:
  /// **'We need your location to show nearby invitations'**
  String get perm_location_desc;

  /// No description provided for @perm_photos_title.
  ///
  /// In en, this message translates to:
  /// **'Access photo gallery'**
  String get perm_photos_title;

  /// No description provided for @perm_photos_desc.
  ///
  /// In en, this message translates to:
  /// **'Required to add photos to your profile'**
  String get perm_photos_desc;

  /// No description provided for @perm_grant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get perm_grant;

  /// No description provided for @perm_not_now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get perm_not_now;

  /// No description provided for @perm_denied_hint.
  ///
  /// In en, this message translates to:
  /// **'You can grant this permission from settings to use this feature'**
  String get perm_denied_hint;

  /// No description provided for @perm_go_to_settings.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get perm_go_to_settings;

  /// No description provided for @feed_all_cities.
  ///
  /// In en, this message translates to:
  /// **'All Cities'**
  String get feed_all_cities;

  /// No description provided for @feed_active_invitations.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE INVITATIONS'**
  String get feed_active_invitations;

  /// No description provided for @feed_active_requests.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE REQUESTS'**
  String get feed_active_requests;

  /// No description provided for @feed_24h_badge.
  ///
  /// In en, this message translates to:
  /// **'24 HRS'**
  String get feed_24h_badge;

  /// No description provided for @feed_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String feed_error(String error);

  /// No description provided for @feed_no_invitations.
  ///
  /// In en, this message translates to:
  /// **'No invitations yet'**
  String get feed_no_invitations;

  /// No description provided for @feed_be_first.
  ///
  /// In en, this message translates to:
  /// **'Be the first to open one!'**
  String get feed_be_first;

  /// No description provided for @feed_todays_invitations.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S INVITATIONS'**
  String get feed_todays_invitations;

  /// No description provided for @feed_todays_requests.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S REQUESTS'**
  String get feed_todays_requests;

  /// No description provided for @feed_swipe_hint.
  ///
  /// In en, this message translates to:
  /// **'· SWIPE →'**
  String get feed_swipe_hint;

  /// No description provided for @feed_cta_invite.
  ///
  /// In en, this message translates to:
  /// **'I want to come'**
  String get feed_cta_invite;

  /// No description provided for @feed_cta_request.
  ///
  /// In en, this message translates to:
  /// **'I want to join'**
  String get feed_cta_request;

  /// No description provided for @feed_city_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get feed_city_picker_title;

  /// No description provided for @feed_city_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search city…'**
  String get feed_city_search_hint;

  /// No description provided for @feed_city_not_found.
  ///
  /// In en, this message translates to:
  /// **'No city found for \"{query}\"'**
  String feed_city_not_found(String query);

  /// No description provided for @feed_tab_invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get feed_tab_invitations;

  /// No description provided for @feed_tab_requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get feed_tab_requests;

  /// No description provided for @feed_city_name_moscow.
  ///
  /// In en, this message translates to:
  /// **'Moscow'**
  String get feed_city_name_moscow;

  /// No description provided for @discover_title.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover_title;

  /// No description provided for @discover_all_invitations_label.
  ///
  /// In en, this message translates to:
  /// **'ALL ACTIVE INVITATIONS'**
  String get discover_all_invitations_label;

  /// No description provided for @discover_filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discover_filter_all;

  /// No description provided for @discover_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No active invitations yet'**
  String get discover_empty_title;

  /// No description provided for @discover_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to open one here'**
  String get discover_empty_subtitle;

  /// No description provided for @discover_btn_create.
  ///
  /// In en, this message translates to:
  /// **'+ Create Invitation'**
  String get discover_btn_create;

  /// No description provided for @discover_error.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get discover_error;

  /// No description provided for @applicants_title.
  ///
  /// In en, this message translates to:
  /// **'Applicants'**
  String get applicants_title;

  /// No description provided for @applicants_count.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String applicants_count(int count);

  /// No description provided for @applicants_empty.
  ///
  /// In en, this message translates to:
  /// **'No applications yet'**
  String get applicants_empty;

  /// No description provided for @applicants_select_btn.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get applicants_select_btn;

  /// No description provided for @applicants_error_already_matched.
  ///
  /// In en, this message translates to:
  /// **'This invitation is already matched'**
  String get applicants_error_already_matched;

  /// No description provided for @applicants_error_not_authorized.
  ///
  /// In en, this message translates to:
  /// **'Authorization error'**
  String get applicants_error_not_authorized;

  /// No description provided for @applicants_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String applicants_error_generic(String message);

  /// No description provided for @create_inv_step_flow_type.
  ///
  /// In en, this message translates to:
  /// **'Invitation type'**
  String get create_inv_step_flow_type;

  /// No description provided for @create_inv_step_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get create_inv_step_category;

  /// No description provided for @create_inv_step_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get create_inv_step_title;

  /// No description provided for @create_inv_step_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get create_inv_step_description;

  /// No description provided for @create_inv_step_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get create_inv_step_venue;

  /// No description provided for @create_inv_step_datetime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get create_inv_step_datetime;

  /// No description provided for @create_inv_step_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get create_inv_step_duration;

  /// No description provided for @create_inv_validation_category.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get create_inv_validation_category;

  /// No description provided for @create_inv_validation_title.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get create_inv_validation_title;

  /// No description provided for @create_inv_validation_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue name cannot be empty'**
  String get create_inv_validation_venue;

  /// No description provided for @create_inv_validation_date.
  ///
  /// In en, this message translates to:
  /// **'Please select a date and time'**
  String get create_inv_validation_date;

  /// No description provided for @create_inv_error_publish.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String create_inv_error_publish(String error);

  /// No description provided for @create_inv_btn_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get create_inv_btn_next;

  /// No description provided for @create_inv_btn_publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get create_inv_btn_publish;

  /// No description provided for @create_inv_flow_invite_title.
  ///
  /// In en, this message translates to:
  /// **'I\'m treating'**
  String get create_inv_flow_invite_title;

  /// No description provided for @create_inv_flow_invite_subtitle.
  ///
  /// In en, this message translates to:
  /// **'I want to take someone along, my treat'**
  String get create_inv_flow_invite_subtitle;

  /// No description provided for @create_inv_flow_request_title.
  ///
  /// In en, this message translates to:
  /// **'I want to go'**
  String get create_inv_flow_request_title;

  /// No description provided for @create_inv_flow_request_subtitle.
  ///
  /// In en, this message translates to:
  /// **'I have a place in mind, looking for someone to join'**
  String get create_inv_flow_request_subtitle;

  /// No description provided for @create_inv_flow_question.
  ///
  /// In en, this message translates to:
  /// **'What do you want to open?'**
  String get create_inv_flow_question;

  /// No description provided for @create_inv_category_question.
  ///
  /// In en, this message translates to:
  /// **'What experience are you sharing?'**
  String get create_inv_category_question;

  /// No description provided for @create_inv_title_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Short and catchy — will appear large in the feed'**
  String get create_inv_title_subtitle;

  /// No description provided for @create_inv_title_label.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get create_inv_title_label;

  /// No description provided for @create_inv_desc_invite_hint.
  ///
  /// In en, this message translates to:
  /// **'Where are you going, what kind of person are you looking for?'**
  String get create_inv_desc_invite_hint;

  /// No description provided for @create_inv_desc_request_hint.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go, what kind of person are you looking for?'**
  String get create_inv_desc_request_hint;

  /// No description provided for @create_inv_desc_input_hint.
  ///
  /// In en, this message translates to:
  /// **'Write the details...'**
  String get create_inv_desc_input_hint;

  /// No description provided for @create_inv_venue_question.
  ///
  /// In en, this message translates to:
  /// **'Where?'**
  String get create_inv_venue_question;

  /// No description provided for @create_inv_venue_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Short venue name — café, restaurant, park'**
  String get create_inv_venue_subtitle;

  /// No description provided for @create_inv_venue_label.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get create_inv_venue_label;

  /// No description provided for @create_inv_venue_placeholder.
  ///
  /// In en, this message translates to:
  /// **'E.g. White Rabbit, Gorki Park...'**
  String get create_inv_venue_placeholder;

  /// No description provided for @create_inv_duration_question.
  ///
  /// In en, this message translates to:
  /// **'How long should the invitation last?'**
  String get create_inv_duration_question;

  /// No description provided for @create_inv_duration_subtitle.
  ///
  /// In en, this message translates to:
  /// **'After this time the invitation disappears from the feed'**
  String get create_inv_duration_subtitle;

  /// No description provided for @create_inv_duration_6h.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get create_inv_duration_6h;

  /// No description provided for @create_inv_duration_6h_desc.
  ///
  /// In en, this message translates to:
  /// **'Short-term — for today'**
  String get create_inv_duration_6h_desc;

  /// No description provided for @create_inv_duration_12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get create_inv_duration_12h;

  /// No description provided for @create_inv_duration_12h_desc.
  ///
  /// In en, this message translates to:
  /// **'Half a day'**
  String get create_inv_duration_12h_desc;

  /// No description provided for @create_inv_duration_24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get create_inv_duration_24h;

  /// No description provided for @create_inv_duration_24h_desc.
  ///
  /// In en, this message translates to:
  /// **'Standard — 1 day'**
  String get create_inv_duration_24h_desc;

  /// No description provided for @create_inv_duration_48h.
  ///
  /// In en, this message translates to:
  /// **'48 hours'**
  String get create_inv_duration_48h;

  /// No description provided for @create_inv_duration_48h_desc.
  ///
  /// In en, this message translates to:
  /// **'Long-term — 2 days'**
  String get create_inv_duration_48h_desc;

  /// No description provided for @create_inv_datetime_question.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get create_inv_datetime_question;

  /// No description provided for @create_inv_datetime_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the event date and time'**
  String get create_inv_datetime_subtitle;

  /// No description provided for @create_inv_datetime_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get create_inv_datetime_placeholder;

  /// No description provided for @decision_selected_title.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been selected!'**
  String get decision_selected_title;

  /// No description provided for @decision_selected_body.
  ///
  /// In en, this message translates to:
  /// **'{name} has selected you for the \"{title}\" invitation.\nDo you want to accept?'**
  String decision_selected_body(String name, String title);

  /// No description provided for @decision_time_remaining.
  ///
  /// In en, this message translates to:
  /// **'time remaining'**
  String get decision_time_remaining;

  /// No description provided for @decision_accept.
  ///
  /// In en, this message translates to:
  /// **'Yes, I accept'**
  String get decision_accept;

  /// No description provided for @decision_reject.
  ///
  /// In en, this message translates to:
  /// **'No, decline'**
  String get decision_reject;

  /// No description provided for @decision_fallback_name.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get decision_fallback_name;

  /// No description provided for @decision_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String decision_error(String error);

  /// No description provided for @inv_detail_not_found.
  ///
  /// In en, this message translates to:
  /// **'Invitation not found'**
  String get inv_detail_not_found;

  /// No description provided for @inv_detail_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete invitation'**
  String get inv_detail_delete_title;

  /// No description provided for @inv_detail_delete_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this invitation? This cannot be undone.'**
  String get inv_detail_delete_body;

  /// No description provided for @inv_detail_delete_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get inv_detail_delete_cancel;

  /// No description provided for @inv_detail_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get inv_detail_delete_confirm;

  /// No description provided for @inv_detail_status_closed.
  ///
  /// In en, this message translates to:
  /// **'This invitation is closed'**
  String get inv_detail_status_closed;

  /// No description provided for @inv_detail_status_meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get inv_detail_status_meeting;

  /// No description provided for @inv_detail_status_decision.
  ///
  /// In en, this message translates to:
  /// **'DECISION TIME'**
  String get inv_detail_status_decision;

  /// No description provided for @inv_detail_status_awaiting.
  ///
  /// In en, this message translates to:
  /// **'AWAITING SELECTION'**
  String get inv_detail_status_awaiting;

  /// No description provided for @inv_detail_status_remaining.
  ///
  /// In en, this message translates to:
  /// **'TIME REMAINING'**
  String get inv_detail_status_remaining;

  /// No description provided for @inv_detail_status_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inv_detail_status_expired;

  /// No description provided for @inv_detail_day_mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get inv_detail_day_mon;

  /// No description provided for @inv_detail_day_tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get inv_detail_day_tue;

  /// No description provided for @inv_detail_day_wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get inv_detail_day_wed;

  /// No description provided for @inv_detail_day_thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get inv_detail_day_thu;

  /// No description provided for @inv_detail_day_fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get inv_detail_day_fri;

  /// No description provided for @inv_detail_day_sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get inv_detail_day_sat;

  /// No description provided for @inv_detail_day_sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get inv_detail_day_sun;

  /// No description provided for @inv_detail_directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get inv_detail_directions;

  /// No description provided for @inv_detail_section_invitation.
  ///
  /// In en, this message translates to:
  /// **'INVITATION'**
  String get inv_detail_section_invitation;

  /// No description provided for @inv_detail_section_details.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get inv_detail_section_details;

  /// No description provided for @inv_detail_section_host.
  ///
  /// In en, this message translates to:
  /// **'HOST'**
  String get inv_detail_section_host;

  /// No description provided for @inv_detail_host_label.
  ///
  /// In en, this message translates to:
  /// **'Invitation host'**
  String get inv_detail_host_label;

  /// No description provided for @inv_detail_applicants_btn.
  ///
  /// In en, this message translates to:
  /// **'View Applicants'**
  String get inv_detail_applicants_btn;

  /// No description provided for @inv_detail_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get inv_detail_loading;

  /// No description provided for @inv_detail_error_label.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get inv_detail_error_label;

  /// No description provided for @inv_detail_apply_invite.
  ///
  /// In en, this message translates to:
  /// **'I want to come'**
  String get inv_detail_apply_invite;

  /// No description provided for @inv_detail_apply_request.
  ///
  /// In en, this message translates to:
  /// **'I want to join'**
  String get inv_detail_apply_request;

  /// No description provided for @inv_detail_apply_sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get inv_detail_apply_sending;

  /// No description provided for @inv_detail_withdraw_title.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application'**
  String get inv_detail_withdraw_title;

  /// No description provided for @inv_detail_withdraw_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to withdraw your application for this invitation?'**
  String get inv_detail_withdraw_body;

  /// No description provided for @inv_detail_withdraw_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get inv_detail_withdraw_cancel;

  /// No description provided for @inv_detail_withdraw_confirm.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get inv_detail_withdraw_confirm;

  /// No description provided for @inv_detail_withdraw_btn.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Application'**
  String get inv_detail_withdraw_btn;

  /// No description provided for @inv_detail_withdrawing.
  ///
  /// In en, this message translates to:
  /// **'Cancelling...'**
  String get inv_detail_withdrawing;

  /// No description provided for @inv_detail_selected_btn.
  ///
  /// In en, this message translates to:
  /// **'Selected — Make your decision'**
  String get inv_detail_selected_btn;

  /// No description provided for @inv_detail_accepted_btn.
  ///
  /// In en, this message translates to:
  /// **'✓ Accepted'**
  String get inv_detail_accepted_btn;

  /// No description provided for @inv_detail_apply_sent_title.
  ///
  /// In en, this message translates to:
  /// **'Application Sent'**
  String get inv_detail_apply_sent_title;

  /// No description provided for @inv_detail_apply_sent_body.
  ///
  /// In en, this message translates to:
  /// **'Wait for the invitation owner to make their choice'**
  String get inv_detail_apply_sent_body;

  /// No description provided for @inv_detail_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String inv_detail_error(String error);

  /// No description provided for @inv_detail_duration_days_hours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String inv_detail_duration_days_hours(int days, int hours);

  /// No description provided for @inv_detail_duration_hours_min.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {min}m'**
  String inv_detail_duration_hours_min(int hours, int min);

  /// No description provided for @inv_detail_duration_min.
  ///
  /// In en, this message translates to:
  /// **'{min}m'**
  String inv_detail_duration_min(int min);

  /// No description provided for @inv_detail_weekday_mon_full.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get inv_detail_weekday_mon_full;

  /// No description provided for @inv_detail_weekday_tue_full.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get inv_detail_weekday_tue_full;

  /// No description provided for @inv_detail_weekday_wed_full.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get inv_detail_weekday_wed_full;

  /// No description provided for @inv_detail_weekday_thu_full.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get inv_detail_weekday_thu_full;

  /// No description provided for @inv_detail_weekday_fri_full.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get inv_detail_weekday_fri_full;

  /// No description provided for @inv_detail_weekday_sat_full.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get inv_detail_weekday_sat_full;

  /// No description provided for @inv_detail_weekday_sun_full.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get inv_detail_weekday_sun_full;

  /// No description provided for @chat_archived.
  ///
  /// In en, this message translates to:
  /// **'This chat is archived'**
  String get chat_archived;

  /// No description provided for @chat_meeting_question.
  ///
  /// In en, this message translates to:
  /// **'Did your meeting happen?'**
  String get chat_meeting_question;

  /// No description provided for @chat_yes_we_met.
  ///
  /// In en, this message translates to:
  /// **'Yes, we met'**
  String get chat_yes_we_met;

  /// No description provided for @chat_other_no_show.
  ///
  /// In en, this message translates to:
  /// **'The other person didn\'t come'**
  String get chat_other_no_show;

  /// No description provided for @chat_send_error.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String chat_send_error(String error);

  /// No description provided for @chat_meeting_saved.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Meeting recorded.'**
  String get chat_meeting_saved;

  /// No description provided for @chat_noted.
  ///
  /// In en, this message translates to:
  /// **'Noted.'**
  String get chat_noted;

  /// No description provided for @chat_other_age.
  ///
  /// In en, this message translates to:
  /// **'{age} years old'**
  String chat_other_age(int age);

  /// No description provided for @chat_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Be the first to send a message!'**
  String get chat_empty_hint;

  /// No description provided for @chat_input_hint.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get chat_input_hint;

  /// No description provided for @messages_title.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages_title;

  /// No description provided for @messages_tab_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get messages_tab_active;

  /// No description provided for @messages_tab_past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get messages_tab_past;

  /// No description provided for @messages_connection_error.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get messages_connection_error;

  /// No description provided for @messages_no_preview.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get messages_no_preview;

  /// No description provided for @messages_empty_past.
  ///
  /// In en, this message translates to:
  /// **'No past chats'**
  String get messages_empty_past;

  /// No description provided for @messages_empty_active.
  ///
  /// In en, this message translates to:
  /// **'No active chats yet'**
  String get messages_empty_active;

  /// No description provided for @messages_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Open an invitation or apply to an existing one'**
  String get messages_empty_hint;

  /// No description provided for @messages_btn_create.
  ///
  /// In en, this message translates to:
  /// **'Create Invitation'**
  String get messages_btn_create;

  /// No description provided for @notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications_title;

  /// No description provided for @notifications_mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifications_mark_all_read;

  /// No description provided for @notifications_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String notifications_error(String error);

  /// No description provided for @notifications_empty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifications_empty;

  /// No description provided for @photo_upload_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit your photos'**
  String get photo_upload_title_edit;

  /// No description provided for @photo_upload_title_add.
  ///
  /// In en, this message translates to:
  /// **'Add your photos'**
  String get photo_upload_title_add;

  /// No description provided for @photo_upload_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Min {min} max {max} photos • {filled} / {total}'**
  String photo_upload_subtitle(int min, int max, int filled, int total);

  /// No description provided for @photo_upload_primary_label.
  ///
  /// In en, this message translates to:
  /// **'Primary photo'**
  String get photo_upload_primary_label;

  /// No description provided for @photo_upload_primary_badge.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get photo_upload_primary_badge;

  /// No description provided for @photo_upload_permission_error.
  ///
  /// In en, this message translates to:
  /// **'Gallery permission required. Please allow from settings.'**
  String get photo_upload_permission_error;

  /// No description provided for @photo_upload_pick_error.
  ///
  /// In en, this message translates to:
  /// **'Could not pick photo: {error}'**
  String photo_upload_pick_error(String error);

  /// No description provided for @photo_upload_error.
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String photo_upload_error(String error);

  /// No description provided for @photo_upload_btn_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get photo_upload_btn_save;

  /// No description provided for @photo_upload_btn_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get photo_upload_btn_continue;

  /// No description provided for @photo_crop_title.
  ///
  /// In en, this message translates to:
  /// **'Edit photo'**
  String get photo_crop_title;

  /// No description provided for @photo_crop_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get photo_crop_apply;

  /// No description provided for @photo_crop_error.
  ///
  /// In en, this message translates to:
  /// **'Crop error: {error}'**
  String photo_crop_error(String error);

  /// No description provided for @profile_setup_step_name_age.
  ///
  /// In en, this message translates to:
  /// **'Name & age'**
  String get profile_setup_step_name_age;

  /// No description provided for @profile_setup_step_gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profile_setup_step_gender;

  /// No description provided for @profile_setup_step_city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profile_setup_step_city;

  /// No description provided for @profile_setup_step_bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profile_setup_step_bio;

  /// No description provided for @profile_setup_step_job_edu.
  ///
  /// In en, this message translates to:
  /// **'Work / Education'**
  String get profile_setup_step_job_edu;

  /// No description provided for @profile_setup_step_interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get profile_setup_step_interests;

  /// No description provided for @profile_setup_step_prompts.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get profile_setup_step_prompts;

  /// No description provided for @profile_setup_step_show_gender.
  ///
  /// In en, this message translates to:
  /// **'Display preference'**
  String get profile_setup_step_show_gender;

  /// No description provided for @profile_setup_step_age_range.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get profile_setup_step_age_range;

  /// No description provided for @profile_setup_validation_name.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get profile_setup_validation_name;

  /// No description provided for @profile_setup_validation_age.
  ///
  /// In en, this message translates to:
  /// **'Age must be between {min} and {max}'**
  String profile_setup_validation_age(int min, int max);

  /// No description provided for @profile_setup_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profile_setup_error(String error);

  /// No description provided for @profile_setup_btn_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get profile_setup_btn_next;

  /// No description provided for @profile_setup_btn_add_photos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get profile_setup_btn_add_photos;

  /// No description provided for @profile_setup_name_question.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get profile_setup_name_question;

  /// No description provided for @profile_setup_name_label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profile_setup_name_label;

  /// No description provided for @profile_setup_age_label.
  ///
  /// In en, this message translates to:
  /// **'Age ({min}-{max})'**
  String profile_setup_age_label(int min, int max);

  /// No description provided for @profile_setup_gender_title.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profile_setup_gender_title;

  /// No description provided for @profile_setup_gender_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get profile_setup_gender_female;

  /// No description provided for @profile_setup_gender_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get profile_setup_gender_male;

  /// No description provided for @profile_setup_city_question.
  ///
  /// In en, this message translates to:
  /// **'What city are you in?'**
  String get profile_setup_city_question;

  /// No description provided for @profile_setup_city_search.
  ///
  /// In en, this message translates to:
  /// **'Search city...'**
  String get profile_setup_city_search;

  /// No description provided for @profile_setup_city_not_found.
  ///
  /// In en, this message translates to:
  /// **'City not found'**
  String get profile_setup_city_not_found;

  /// No description provided for @profile_setup_bio_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get profile_setup_bio_title;

  /// No description provided for @profile_setup_bio_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional — max 200 characters'**
  String get profile_setup_bio_subtitle;

  /// No description provided for @profile_setup_bio_hint.
  ///
  /// In en, this message translates to:
  /// **'Briefly introduce yourself...'**
  String get profile_setup_bio_hint;

  /// No description provided for @profile_setup_job_title.
  ///
  /// In en, this message translates to:
  /// **'Work & Education'**
  String get profile_setup_job_title;

  /// No description provided for @profile_setup_job_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get profile_setup_job_subtitle;

  /// No description provided for @profile_setup_job_label.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get profile_setup_job_label;

  /// No description provided for @profile_setup_education_label.
  ///
  /// In en, this message translates to:
  /// **'School / University'**
  String get profile_setup_education_label;

  /// No description provided for @profile_setup_interests_title.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get profile_setup_interests_title;

  /// No description provided for @profile_setup_interests_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select at least 3'**
  String get profile_setup_interests_subtitle;

  /// No description provided for @profile_setup_prompts_title.
  ///
  /// In en, this message translates to:
  /// **'A few questions'**
  String get profile_setup_prompts_title;

  /// No description provided for @profile_setup_prompts_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional — enriches your profile'**
  String get profile_setup_prompts_subtitle;

  /// No description provided for @profile_setup_prompts_answer_hint.
  ///
  /// In en, this message translates to:
  /// **'Your answer...'**
  String get profile_setup_prompts_answer_hint;

  /// No description provided for @profile_setup_show_gender_title.
  ///
  /// In en, this message translates to:
  /// **'Whose invitations do you want to see?'**
  String get profile_setup_show_gender_title;

  /// No description provided for @profile_setup_show_gender_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only invitations from these people will appear in your feed'**
  String get profile_setup_show_gender_subtitle;

  /// No description provided for @profile_setup_show_gender_opposite.
  ///
  /// In en, this message translates to:
  /// **'Opposite gender'**
  String get profile_setup_show_gender_opposite;

  /// No description provided for @profile_setup_show_gender_all.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get profile_setup_show_gender_all;

  /// No description provided for @profile_setup_show_gender_female.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get profile_setup_show_gender_female;

  /// No description provided for @profile_setup_show_gender_male.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get profile_setup_show_gender_male;

  /// No description provided for @profile_setup_age_range_title.
  ///
  /// In en, this message translates to:
  /// **'What age range are you looking for?'**
  String get profile_setup_age_range_title;

  /// No description provided for @profile_setup_age_range_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only invitations in this age range will appear in your feed'**
  String get profile_setup_age_range_subtitle;

  /// No description provided for @profile_setup_age_range_value.
  ///
  /// In en, this message translates to:
  /// **'{min} — {max} years'**
  String profile_setup_age_range_value(int min, int max);

  /// No description provided for @profile_setup_prompt_favorite_restaurant.
  ///
  /// In en, this message translates to:
  /// **'My favourite restaurant...'**
  String get profile_setup_prompt_favorite_restaurant;

  /// No description provided for @profile_setup_prompt_last_book.
  ///
  /// In en, this message translates to:
  /// **'The last book I read...'**
  String get profile_setup_prompt_last_book;

  /// No description provided for @profile_setup_prompt_perfect_evening.
  ///
  /// In en, this message translates to:
  /// **'A perfect evening...'**
  String get profile_setup_prompt_perfect_evening;

  /// No description provided for @profile_setup_prompt_travel_dream.
  ///
  /// In en, this message translates to:
  /// **'My dream trip...'**
  String get profile_setup_prompt_travel_dream;

  /// No description provided for @profile_setup_interest_art.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get profile_setup_interest_art;

  /// No description provided for @profile_setup_interest_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get profile_setup_interest_music;

  /// No description provided for @profile_setup_interest_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get profile_setup_interest_sports;

  /// No description provided for @profile_setup_interest_books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get profile_setup_interest_books;

  /// No description provided for @profile_setup_interest_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get profile_setup_interest_travel;

  /// No description provided for @profile_setup_interest_food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get profile_setup_interest_food;

  /// No description provided for @profile_setup_interest_film.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get profile_setup_interest_film;

  /// No description provided for @profile_setup_interest_theatre.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get profile_setup_interest_theatre;

  /// No description provided for @profile_setup_interest_dance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get profile_setup_interest_dance;

  /// No description provided for @profile_setup_interest_yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get profile_setup_interest_yoga;

  /// No description provided for @profile_setup_interest_photography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get profile_setup_interest_photography;

  /// No description provided for @profile_setup_interest_games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get profile_setup_interest_games;

  /// No description provided for @profile_setup_interest_technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get profile_setup_interest_technology;

  /// No description provided for @profile_setup_interest_nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get profile_setup_interest_nature;

  /// No description provided for @profile_setup_interest_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get profile_setup_interest_history;

  /// No description provided for @profile_setup_interest_fashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get profile_setup_interest_fashion;

  /// No description provided for @profile_view_not_found.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profile_view_not_found;

  /// No description provided for @profile_view_hint_name_age.
  ///
  /// In en, this message translates to:
  /// **'Name and age missing'**
  String get profile_view_hint_name_age;

  /// No description provided for @profile_view_hint_photo.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get profile_view_hint_photo;

  /// No description provided for @profile_view_hint_bio.
  ///
  /// In en, this message translates to:
  /// **'Add a bio'**
  String get profile_view_hint_bio;

  /// No description provided for @profile_view_hint_interests.
  ///
  /// In en, this message translates to:
  /// **'Add interests'**
  String get profile_view_hint_interests;

  /// No description provided for @profile_view_hint_selfie_pending.
  ///
  /// In en, this message translates to:
  /// **'Selfie under review...'**
  String get profile_view_hint_selfie_pending;

  /// No description provided for @profile_view_hint_selfie_upload.
  ///
  /// In en, this message translates to:
  /// **'Upload selfie'**
  String get profile_view_hint_selfie_upload;

  /// No description provided for @profile_view_hint_prompt.
  ///
  /// In en, this message translates to:
  /// **'Answer a question'**
  String get profile_view_hint_prompt;

  /// No description provided for @profile_view_completion.
  ///
  /// In en, this message translates to:
  /// **'{score}% complete'**
  String profile_view_completion(int score);

  /// No description provided for @profile_view_section_interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get profile_view_section_interests;

  /// No description provided for @profile_view_section_prompts.
  ///
  /// In en, this message translates to:
  /// **'Expressions'**
  String get profile_view_section_prompts;

  /// No description provided for @profile_view_cta_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profile_view_cta_edit;

  /// No description provided for @profile_view_cta_come.
  ///
  /// In en, this message translates to:
  /// **'I want to come'**
  String get profile_view_cta_come;

  /// No description provided for @profile_view_action_block.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get profile_view_action_block;

  /// No description provided for @profile_view_action_block_confirm.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get profile_view_action_block_confirm;

  /// No description provided for @profile_view_action_block_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profile_view_action_block_cancel;

  /// No description provided for @profile_view_action_report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get profile_view_action_report;

  /// No description provided for @profile_view_action_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profile_view_action_cancel;

  /// No description provided for @profile_view_blocked_snack.
  ///
  /// In en, this message translates to:
  /// **'{name} blocked'**
  String profile_view_blocked_snack(String name);

  /// No description provided for @profile_view_block_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block this user?'**
  String get profile_view_block_confirm_body;

  /// No description provided for @profile_view_anonymous_user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profile_view_anonymous_user;

  /// No description provided for @report_title.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get report_title;

  /// No description provided for @report_why.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting?'**
  String get report_why;

  /// No description provided for @report_reason_inappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content / photo'**
  String get report_reason_inappropriate;

  /// No description provided for @report_reason_harassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or threats'**
  String get report_reason_harassment;

  /// No description provided for @report_reason_spam.
  ///
  /// In en, this message translates to:
  /// **'Spam or fake account'**
  String get report_reason_spam;

  /// No description provided for @report_reason_illegal.
  ///
  /// In en, this message translates to:
  /// **'Illegal activity'**
  String get report_reason_illegal;

  /// No description provided for @report_reason_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get report_reason_other;

  /// No description provided for @report_desc_label.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get report_desc_label;

  /// No description provided for @report_desc_hint.
  ///
  /// In en, this message translates to:
  /// **'You can add more detail...'**
  String get report_desc_hint;

  /// No description provided for @report_btn_sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get report_btn_sending;

  /// No description provided for @report_btn_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get report_btn_submit;

  /// No description provided for @report_error_no_reason.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason'**
  String get report_error_no_reason;

  /// No description provided for @report_success.
  ///
  /// In en, this message translates to:
  /// **'Your report has been received, we will review it'**
  String get report_success;

  /// No description provided for @report_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String report_error(String error);

  /// No description provided for @selfie_title.
  ///
  /// In en, this message translates to:
  /// **'Selfie verification'**
  String get selfie_title;

  /// No description provided for @selfie_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We manually verify your profile for a safe community'**
  String get selfie_subtitle;

  /// No description provided for @selfie_take_btn.
  ///
  /// In en, this message translates to:
  /// **'Take selfie'**
  String get selfie_take_btn;

  /// No description provided for @selfie_tip_lighting.
  ///
  /// In en, this message translates to:
  /// **'Take in a well-lit environment'**
  String get selfie_tip_lighting;

  /// No description provided for @selfie_tip_face.
  ///
  /// In en, this message translates to:
  /// **'Your face should be clearly visible'**
  String get selfie_tip_face;

  /// No description provided for @selfie_tip_approval.
  ///
  /// In en, this message translates to:
  /// **'Admin approves within 24 hours'**
  String get selfie_tip_approval;

  /// No description provided for @selfie_submit_btn.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get selfie_submit_btn;

  /// No description provided for @blocked_users_title.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blocked_users_title;

  /// No description provided for @blocked_users_empty.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get blocked_users_empty;

  /// No description provided for @blocked_users_unblock_btn.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blocked_users_unblock_btn;

  /// No description provided for @delete_account_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account_title;

  /// No description provided for @delete_account_heading.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get delete_account_heading;

  /// No description provided for @delete_account_body.
  ///
  /// In en, this message translates to:
  /// **'If you delete your account, all your data, messages, matches and photos will be permanently deleted. This cannot be undone.'**
  String get delete_account_body;

  /// No description provided for @delete_account_warn_profile.
  ///
  /// In en, this message translates to:
  /// **'Your profile and all photos will be deleted'**
  String get delete_account_warn_profile;

  /// No description provided for @delete_account_warn_messages.
  ///
  /// In en, this message translates to:
  /// **'Your entire message history will be deleted'**
  String get delete_account_warn_messages;

  /// No description provided for @delete_account_warn_invitations.
  ///
  /// In en, this message translates to:
  /// **'Your active invitations and applications will be deleted'**
  String get delete_account_warn_invitations;

  /// No description provided for @delete_account_warn_phone.
  ///
  /// In en, this message translates to:
  /// **'You cannot re-register with the same phone number'**
  String get delete_account_warn_phone;

  /// No description provided for @delete_account_checkbox.
  ///
  /// In en, this message translates to:
  /// **'Yes, I want to permanently delete my account'**
  String get delete_account_checkbox;

  /// No description provided for @delete_account_btn_delete.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete Account'**
  String get delete_account_btn_delete;

  /// No description provided for @delete_account_btn_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get delete_account_btn_cancel;

  /// No description provided for @delete_account_success.
  ///
  /// In en, this message translates to:
  /// **'Your account has been marked for deletion. It will be permanently removed shortly.'**
  String get delete_account_success;

  /// No description provided for @delete_account_error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get delete_account_error;

  /// No description provided for @settings_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon.'**
  String get settings_coming_soon;

  /// No description provided for @settings_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get settings_ok;

  /// No description provided for @settings_about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium social invitation app.'**
  String get settings_about_subtitle;

  /// No description provided for @settings_share_subject.
  ///
  /// In en, this message translates to:
  /// **'SoulChoice Data Export'**
  String get settings_share_subject;

  /// No description provided for @settings_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String settings_error(String error);

  /// No description provided for @settings_quiet_hours_title.
  ///
  /// In en, this message translates to:
  /// **'Night quiet hours'**
  String get settings_quiet_hours_title;

  /// No description provided for @settings_quiet_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settings_quiet_active;

  /// No description provided for @settings_quiet_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settings_quiet_start;

  /// No description provided for @settings_quiet_end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get settings_quiet_end;

  /// No description provided for @settings_age_range_title.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get settings_age_range_title;

  /// No description provided for @settings_age_range_value.
  ///
  /// In en, this message translates to:
  /// **'{min} — {max} years'**
  String settings_age_range_value(int min, int max);

  /// No description provided for @settings_display_pref_title.
  ///
  /// In en, this message translates to:
  /// **'Display preference'**
  String get settings_display_pref_title;

  /// No description provided for @settings_privacy_section.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & SECURITY'**
  String get settings_privacy_section;

  /// No description provided for @settings_blocked_users.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get settings_blocked_users;

  /// No description provided for @settings_location_permission.
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get settings_location_permission;

  /// No description provided for @settings_camera_permission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission'**
  String get settings_camera_permission;

  /// No description provided for @settings_support_section.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get settings_support_section;

  /// No description provided for @settings_help.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settings_help;

  /// No description provided for @settings_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// No description provided for @settings_logout_error.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out. Please try again.'**
  String get settings_logout_error;

  /// No description provided for @settings_selfie_pending.
  ///
  /// In en, this message translates to:
  /// **'Selfie under review'**
  String get settings_selfie_pending;

  /// No description provided for @settings_selfie_approved.
  ///
  /// In en, this message translates to:
  /// **'Verified account'**
  String get settings_selfie_approved;

  /// No description provided for @settings_selfie_rejected.
  ///
  /// In en, this message translates to:
  /// **'Selfie rejected — re-upload'**
  String get settings_selfie_rejected;

  /// No description provided for @settings_selfie_none.
  ///
  /// In en, this message translates to:
  /// **'No selfie uploaded yet'**
  String get settings_selfie_none;

  /// No description provided for @settings_verification_status.
  ///
  /// In en, this message translates to:
  /// **'Verification status'**
  String get settings_verification_status;

  /// No description provided for @settings_reupload.
  ///
  /// In en, this message translates to:
  /// **'Re-upload'**
  String get settings_reupload;

  /// No description provided for @settings_show_gender_opposite.
  ///
  /// In en, this message translates to:
  /// **'Opposite gender'**
  String get settings_show_gender_opposite;

  /// No description provided for @settings_show_gender_all.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get settings_show_gender_all;

  /// No description provided for @settings_show_gender_female.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get settings_show_gender_female;

  /// No description provided for @settings_show_gender_male.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get settings_show_gender_male;

  /// No description provided for @admin_title.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get admin_title;

  /// No description provided for @admin_tab_selfies.
  ///
  /// In en, this message translates to:
  /// **'Selfie Reviews'**
  String get admin_tab_selfies;

  /// No description provided for @admin_tab_reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get admin_tab_reports;

  /// No description provided for @admin_reject_reason_title.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get admin_reject_reason_title;

  /// No description provided for @admin_reject_reason_no_face.
  ///
  /// In en, this message translates to:
  /// **'Face not visible'**
  String get admin_reject_reason_no_face;

  /// No description provided for @admin_reject_reason_inappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get admin_reject_reason_inappropriate;

  /// No description provided for @admin_reject_reason_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Different person (doesn\'t match profile photo)'**
  String get admin_reject_reason_mismatch;

  /// No description provided for @admin_reject_reason_quality.
  ///
  /// In en, this message translates to:
  /// **'Low quality / blurry'**
  String get admin_reject_reason_quality;

  /// No description provided for @admin_reject_reason_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get admin_reject_reason_other;

  /// No description provided for @admin_btn_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get admin_btn_cancel;

  /// No description provided for @admin_btn_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get admin_btn_reject;

  /// No description provided for @admin_selfies_empty.
  ///
  /// In en, this message translates to:
  /// **'No pending selfies'**
  String get admin_selfies_empty;

  /// No description provided for @admin_view_profile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get admin_view_profile;

  /// No description provided for @admin_photo_label_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get admin_photo_label_profile;

  /// No description provided for @admin_photo_label_selfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get admin_photo_label_selfie;

  /// No description provided for @admin_btn_approve.
  ///
  /// In en, this message translates to:
  /// **'✅ Approve'**
  String get admin_btn_approve;

  /// No description provided for @admin_btn_reject_action.
  ///
  /// In en, this message translates to:
  /// **'❌ Reject'**
  String get admin_btn_reject_action;

  /// No description provided for @admin_reports_empty.
  ///
  /// In en, this message translates to:
  /// **'No pending reports'**
  String get admin_reports_empty;

  /// No description provided for @admin_report_about.
  ///
  /// In en, this message translates to:
  /// **'report about {name}'**
  String admin_report_about(String name);

  /// No description provided for @admin_reporter_label.
  ///
  /// In en, this message translates to:
  /// **'Reporter: {name}'**
  String admin_reporter_label(String name);

  /// No description provided for @admin_reason_label.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String admin_reason_label(String reason);

  /// No description provided for @admin_user_banned.
  ///
  /// In en, this message translates to:
  /// **'User banned'**
  String get admin_user_banned;

  /// No description provided for @admin_btn_ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get admin_btn_ban;

  /// No description provided for @admin_btn_dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get admin_btn_dismiss;

  /// No description provided for @category_food.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get category_food;

  /// No description provided for @category_concert.
  ///
  /// In en, this message translates to:
  /// **'Concert'**
  String get category_concert;

  /// No description provided for @category_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get category_travel;

  /// No description provided for @category_culture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get category_culture;

  /// No description provided for @category_cinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get category_cinema;

  /// No description provided for @category_theater.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get category_theater;

  /// No description provided for @category_coffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get category_coffee;

  /// No description provided for @category_bar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get category_bar;

  /// No description provided for @category_gift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get category_gift;
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
      <String>['en', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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
