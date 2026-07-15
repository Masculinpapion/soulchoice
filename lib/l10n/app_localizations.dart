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
  /// **'PROFILE'**
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

  /// No description provided for @notif_pref_push_section.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notif_pref_push_section;

  /// No description provided for @notif_pref_new_application.
  ///
  /// In en, this message translates to:
  /// **'New applications'**
  String get notif_pref_new_application;

  /// No description provided for @notif_pref_new_application_sub.
  ///
  /// In en, this message translates to:
  /// **'Someone responded to your invitation'**
  String get notif_pref_new_application_sub;

  /// No description provided for @notif_pref_selected.
  ///
  /// In en, this message translates to:
  /// **'You\'re selected'**
  String get notif_pref_selected;

  /// No description provided for @notif_pref_selected_sub.
  ///
  /// In en, this message translates to:
  /// **'Your application was accepted — chat opens'**
  String get notif_pref_selected_sub;

  /// No description provided for @notif_pref_message.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notif_pref_message;

  /// No description provided for @notif_pref_message_sub.
  ///
  /// In en, this message translates to:
  /// **'New messages in chats'**
  String get notif_pref_message_sub;

  /// No description provided for @notif_pref_match.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get notif_pref_match;

  /// No description provided for @notif_pref_match_sub.
  ///
  /// In en, this message translates to:
  /// **'Mutual selection'**
  String get notif_pref_match_sub;

  /// No description provided for @notif_pref_saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get notif_pref_saved;

  /// No description provided for @notif_pref_all_read.
  ///
  /// In en, this message translates to:
  /// **'All notifications read'**
  String get notif_pref_all_read;

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
  /// **'By continuing you accept our'**
  String get phone_terms;

  /// No description provided for @phone_terms_link_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get phone_terms_link_privacy;

  /// No description provided for @phone_terms_link_terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get phone_terms_link_terms;

  /// No description provided for @otp_title.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otp_title;

  /// No description provided for @otp_sent_to.
  ///
  /// In en, this message translates to:
  /// **'Incoming call to '**
  String get otp_sent_to;

  /// No description provided for @otp_call_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter the last 4 digits of the incoming number'**
  String get otp_call_hint;

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

  /// No description provided for @perm_camera_title.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access'**
  String get perm_camera_title;

  /// No description provided for @perm_camera_desc.
  ///
  /// In en, this message translates to:
  /// **'Required to take a selfie for identity verification'**
  String get perm_camera_desc;

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

  /// No description provided for @create_inv_btn_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get create_inv_btn_update;

  /// No description provided for @edit_inv_title.
  ///
  /// In en, this message translates to:
  /// **'Edit invitation'**
  String get edit_inv_title;

  /// No description provided for @create_inv_flow_invite_title.
  ///
  /// In en, this message translates to:
  /// **'I\'m Hosting'**
  String get create_inv_flow_invite_title;

  /// No description provided for @create_inv_flow_invite_subtitle.
  ///
  /// In en, this message translates to:
  /// **''**
  String get create_inv_flow_invite_subtitle;

  /// No description provided for @create_inv_flow_request_title.
  ///
  /// In en, this message translates to:
  /// **'Seeking Invite'**
  String get create_inv_flow_request_title;

  /// No description provided for @create_inv_flow_request_subtitle.
  ///
  /// In en, this message translates to:
  /// **''**
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
  /// **'Where are you going?'**
  String get create_inv_desc_invite_hint;

  /// No description provided for @create_inv_desc_request_hint.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
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
  /// **'E.g. Cafe Pushkin, Strelka Bar...'**
  String get create_inv_venue_placeholder;

  /// No description provided for @create_inv_duration_question.
  ///
  /// In en, this message translates to:
  /// **'Validity period'**
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

  /// No description provided for @create_inv_venue_ph_food.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get create_inv_venue_ph_food;

  /// No description provided for @create_inv_venue_ph_bar.
  ///
  /// In en, this message translates to:
  /// **'Bar name'**
  String get create_inv_venue_ph_bar;

  /// No description provided for @create_inv_venue_ph_coffee.
  ///
  /// In en, this message translates to:
  /// **'Café name'**
  String get create_inv_venue_ph_coffee;

  /// No description provided for @create_inv_venue_ph_sport.
  ///
  /// In en, this message translates to:
  /// **'Court or club name'**
  String get create_inv_venue_ph_sport;

  /// No description provided for @create_inv_venue_ph_walk.
  ///
  /// In en, this message translates to:
  /// **'Park or meeting spot'**
  String get create_inv_venue_ph_walk;

  /// No description provided for @create_inv_venue_ph_karaoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke bar name'**
  String get create_inv_venue_ph_karaoke;

  /// No description provided for @create_inv_venue_ph_cinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema name'**
  String get create_inv_venue_ph_cinema;

  /// No description provided for @create_inv_venue_ph_theater.
  ///
  /// In en, this message translates to:
  /// **'Theatre name'**
  String get create_inv_venue_ph_theater;

  /// No description provided for @create_inv_venue_ph_concert.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get create_inv_venue_ph_concert;

  /// No description provided for @create_inv_venue_ph_culture.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get create_inv_venue_ph_culture;

  /// No description provided for @create_inv_venue_ph_travel.
  ///
  /// In en, this message translates to:
  /// **'City or country'**
  String get create_inv_venue_ph_travel;

  /// No description provided for @create_inv_venue_ph_gift.
  ///
  /// In en, this message translates to:
  /// **'Where shall we meet?'**
  String get create_inv_venue_ph_gift;

  /// No description provided for @create_inv_validation_description_travel.
  ///
  /// In en, this message translates to:
  /// **'Please write where you want to go'**
  String get create_inv_validation_description_travel;

  /// No description provided for @create_inv_venue_question_gift_invite.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to hand over the gift?'**
  String get create_inv_venue_question_gift_invite;

  /// No description provided for @create_inv_venue_question_gift_request.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to receive the gift?'**
  String get create_inv_venue_question_gift_request;

  /// No description provided for @create_inv_gift_url_label.
  ///
  /// In en, this message translates to:
  /// **'Product link or name (optional)'**
  String get create_inv_gift_url_label;

  /// No description provided for @create_inv_gift_url_hint.
  ///
  /// In en, this message translates to:
  /// **'Link (goldapple, ozon…) or product name'**
  String get create_inv_gift_url_hint;

  /// No description provided for @create_inv_gift_url_helper.
  ///
  /// In en, this message translates to:
  /// **'Only the person you pick sees it · after moderation'**
  String get create_inv_gift_url_helper;

  /// No description provided for @create_inv_gift_url_invalid.
  ///
  /// In en, this message translates to:
  /// **'Known stores only: goldapple, wildberries, ozon, market.yandex, lamoda, letoile'**
  String get create_inv_gift_url_invalid;

  /// No description provided for @create_inv_venue_subtitle_gift.
  ///
  /// In en, this message translates to:
  /// **'The meeting point where you\'ll hand over the gift'**
  String get create_inv_venue_subtitle_gift;

  /// No description provided for @create_inv_venue_subtitle_gift_request.
  ///
  /// In en, this message translates to:
  /// **'The meeting point where you\'ll receive the gift'**
  String get create_inv_venue_subtitle_gift_request;

  /// No description provided for @create_inv_venue_question_cinema.
  ///
  /// In en, this message translates to:
  /// **'Which cinema?'**
  String get create_inv_venue_question_cinema;

  /// No description provided for @create_inv_venue_subtitle_cinema.
  ///
  /// In en, this message translates to:
  /// **'The cinema where you\'ll watch the movie'**
  String get create_inv_venue_subtitle_cinema;

  /// No description provided for @create_inv_venue_question_theater.
  ///
  /// In en, this message translates to:
  /// **'Which theatre?'**
  String get create_inv_venue_question_theater;

  /// No description provided for @create_inv_venue_subtitle_theater.
  ///
  /// In en, this message translates to:
  /// **'The theatre where the play will take place'**
  String get create_inv_venue_subtitle_theater;

  /// No description provided for @create_inv_venue_question_concert.
  ///
  /// In en, this message translates to:
  /// **'Which venue?'**
  String get create_inv_venue_question_concert;

  /// No description provided for @create_inv_venue_subtitle_concert.
  ///
  /// In en, this message translates to:
  /// **'The venue where the event will take place'**
  String get create_inv_venue_subtitle_concert;

  /// No description provided for @create_inv_desc_invite_food.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get create_inv_desc_invite_food;

  /// No description provided for @create_inv_desc_invite_bar.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get create_inv_desc_invite_bar;

  /// No description provided for @create_inv_desc_invite_coffee.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get create_inv_desc_invite_coffee;

  /// No description provided for @create_inv_desc_invite_cinema.
  ///
  /// In en, this message translates to:
  /// **'Film title?'**
  String get create_inv_desc_invite_cinema;

  /// No description provided for @create_inv_desc_invite_theater.
  ///
  /// In en, this message translates to:
  /// **'Play title?'**
  String get create_inv_desc_invite_theater;

  /// No description provided for @create_inv_desc_invite_concert.
  ///
  /// In en, this message translates to:
  /// **'Event name?'**
  String get create_inv_desc_invite_concert;

  /// No description provided for @create_inv_desc_invite_culture.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get create_inv_desc_invite_culture;

  /// No description provided for @create_inv_desc_invite_travel.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get create_inv_desc_invite_travel;

  /// No description provided for @create_inv_desc_invite_gift.
  ///
  /// In en, this message translates to:
  /// **'What would you like to give?'**
  String get create_inv_desc_invite_gift;

  /// No description provided for @create_inv_desc_request_food.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get create_inv_desc_request_food;

  /// No description provided for @create_inv_desc_request_bar.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get create_inv_desc_request_bar;

  /// No description provided for @create_inv_desc_request_coffee.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get create_inv_desc_request_coffee;

  /// No description provided for @create_inv_desc_request_cinema.
  ///
  /// In en, this message translates to:
  /// **'Which film do you want to see?'**
  String get create_inv_desc_request_cinema;

  /// No description provided for @create_inv_desc_request_theater.
  ///
  /// In en, this message translates to:
  /// **'Which play do you want to see?'**
  String get create_inv_desc_request_theater;

  /// No description provided for @create_inv_desc_request_concert.
  ///
  /// In en, this message translates to:
  /// **'Which event do you want to attend?'**
  String get create_inv_desc_request_concert;

  /// No description provided for @create_inv_desc_request_culture.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get create_inv_desc_request_culture;

  /// No description provided for @create_inv_desc_request_travel.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get create_inv_desc_request_travel;

  /// No description provided for @create_inv_desc_invite_sport.
  ///
  /// In en, this message translates to:
  /// **'What\'s the activity?'**
  String get create_inv_desc_invite_sport;

  /// No description provided for @create_inv_desc_request_sport.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get create_inv_desc_request_sport;

  /// No description provided for @create_inv_desc_invite_walk.
  ///
  /// In en, this message translates to:
  /// **'Where are you walking?'**
  String get create_inv_desc_invite_walk;

  /// No description provided for @create_inv_desc_request_walk.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to walk?'**
  String get create_inv_desc_request_walk;

  /// No description provided for @create_inv_desc_invite_karaoke.
  ///
  /// In en, this message translates to:
  /// **'Where are you singing?'**
  String get create_inv_desc_invite_karaoke;

  /// No description provided for @create_inv_desc_request_karaoke.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to sing?'**
  String get create_inv_desc_request_karaoke;

  /// No description provided for @create_inv_desc_request_gift.
  ///
  /// In en, this message translates to:
  /// **'What would you like to receive?'**
  String get create_inv_desc_request_gift;

  /// No description provided for @create_inv_datetime_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get create_inv_datetime_placeholder;

  /// No description provided for @decision_selected_title.
  ///
  /// In en, this message translates to:
  /// **'Match Confirmation'**
  String get decision_selected_title;

  /// No description provided for @decision_selected_body.
  ///
  /// In en, this message translates to:
  /// **'You selected {name} for your \"{title}\" invitation.\nWould you like to confirm this match?'**
  String decision_selected_body(String name, String title);

  /// No description provided for @decision_time_remaining.
  ///
  /// In en, this message translates to:
  /// **'time remaining'**
  String get decision_time_remaining;

  /// No description provided for @decision_time_expired.
  ///
  /// In en, this message translates to:
  /// **'Time expired'**
  String get decision_time_expired;

  /// No description provided for @decision_accept.
  ///
  /// In en, this message translates to:
  /// **'Yes, confirm'**
  String get decision_accept;

  /// No description provided for @decision_reject.
  ///
  /// In en, this message translates to:
  /// **'No, cancel'**
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
  String inv_detail_delete_body(String gender);

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

  /// No description provided for @inv_detail_status_selecting.
  ///
  /// In en, this message translates to:
  /// **'SELECTION WINDOW'**
  String get inv_detail_status_selecting;

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

  /// No description provided for @inv_detail_status_not_selected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get inv_detail_status_not_selected;

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

  /// No description provided for @inv_detail_section_with_whom.
  ///
  /// In en, this message translates to:
  /// **'WITH'**
  String get inv_detail_section_with_whom;

  /// No description provided for @inv_detail_section_who.
  ///
  /// In en, this message translates to:
  /// **'WHO'**
  String get inv_detail_section_who;

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
  String inv_detail_withdraw_body(String gender);

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

  /// No description provided for @inv_detail_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get inv_detail_retry;

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

  /// No description provided for @chat_deleted_user.
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get chat_deleted_user;

  /// No description provided for @chat_gift_link_label.
  ///
  /// In en, this message translates to:
  /// **'Gift item — view'**
  String get chat_gift_link_label;

  /// No description provided for @chat_gift_text_label.
  ///
  /// In en, this message translates to:
  /// **'Gift item'**
  String get chat_gift_text_label;

  /// No description provided for @chat_gift_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'This purchase happens outside SoulChoice, in a third-party store; users are responsible.'**
  String get chat_gift_disclaimer;

  /// No description provided for @notif_selected_push_title.
  ///
  /// In en, this message translates to:
  /// **'You\'re selected! 🎉'**
  String get notif_selected_push_title;

  /// No description provided for @notif_selected_push_body.
  ///
  /// In en, this message translates to:
  /// **'Chat is open — say hello'**
  String get notif_selected_push_body;

  /// No description provided for @chat_deleted_user_info.
  ///
  /// In en, this message translates to:
  /// **'This user deleted their account. You can no longer send messages.'**
  String get chat_deleted_user_info;

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

  /// No description provided for @messages_new_match.
  ///
  /// In en, this message translates to:
  /// **'New match ✨'**
  String get messages_new_match;

  /// No description provided for @chat_selected_welcome.
  ///
  /// In en, this message translates to:
  /// **'{name} chose you — you can now chat 🎉'**
  String chat_selected_welcome(String name);

  /// No description provided for @profile_view_cta_message.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get profile_view_cta_message;

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

  /// No description provided for @profile_setup_step_age_range.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get profile_setup_step_age_range;

  /// No description provided for @profile_setup_step_consent.
  ///
  /// In en, this message translates to:
  /// **'Consent'**
  String get profile_setup_step_consent;

  /// No description provided for @profile_setup_consent_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Before continuing, please confirm the three items below.'**
  String get profile_setup_consent_subtitle;

  /// No description provided for @profile_setup_consent_age.
  ///
  /// In en, this message translates to:
  /// **'I am 18 years of age or older'**
  String get profile_setup_consent_age;

  /// No description provided for @profile_setup_consent_data.
  ///
  /// In en, this message translates to:
  /// **'I consent to the processing of my personal data in accordance with the'**
  String get profile_setup_consent_data;

  /// No description provided for @profile_setup_consent_data_link.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profile_setup_consent_data_link;

  /// No description provided for @profile_setup_consent_visibility.
  ///
  /// In en, this message translates to:
  /// **'I allow my profile (photo, name, age, city) to be shown to other users of the service'**
  String get profile_setup_consent_visibility;

  /// No description provided for @profile_setup_validation_gender.
  ///
  /// In en, this message translates to:
  /// **'Please select a gender'**
  String get profile_setup_validation_gender;

  /// No description provided for @profile_setup_validation_city.
  ///
  /// In en, this message translates to:
  /// **'Please select a city'**
  String get profile_setup_validation_city;

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
  /// **'MY FAVOURITE RESTAURANT...'**
  String get profile_setup_prompt_favorite_restaurant;

  /// No description provided for @profile_setup_prompt_last_book.
  ///
  /// In en, this message translates to:
  /// **'THE LAST BOOK I READ...'**
  String profile_setup_prompt_last_book(String gender);

  /// No description provided for @profile_setup_prompt_perfect_evening.
  ///
  /// In en, this message translates to:
  /// **'A PERFECT EVENING...'**
  String get profile_setup_prompt_perfect_evening;

  /// No description provided for @profile_setup_prompt_travel_dream.
  ///
  /// In en, this message translates to:
  /// **'MY DREAM TRIP...'**
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
  /// **'INTERESTS'**
  String get profile_view_section_interests;

  /// No description provided for @profile_view_section_prompts.
  ///
  /// In en, this message translates to:
  /// **'EXPRESSIONS'**
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
  String profile_view_blocked_snack(String name, String gender);

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

  /// No description provided for @report_desc_label_required.
  ///
  /// In en, this message translates to:
  /// **'Description (required)'**
  String get report_desc_label_required;

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

  /// No description provided for @report_error_desc_required.
  ///
  /// In en, this message translates to:
  /// **'Please add a description for \"Other\"'**
  String get report_error_desc_required;

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
  /// **'Blocked'**
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

  /// No description provided for @settings_privacy_section.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & SECURITY'**
  String get settings_privacy_section;

  /// No description provided for @settings_blocked_users.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
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

  /// No description provided for @category_sport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get category_sport;

  /// No description provided for @category_walk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get category_walk;

  /// No description provided for @category_karaoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke'**
  String get category_karaoke;

  /// No description provided for @notif_type_new_application_title.
  ///
  /// In en, this message translates to:
  /// **'New Application'**
  String get notif_type_new_application_title;

  /// No description provided for @notif_type_new_application_body.
  ///
  /// In en, this message translates to:
  /// **'{name} applied to your invitation'**
  String notif_type_new_application_body(String name);

  /// No description provided for @notif_type_selected_title.
  ///
  /// In en, this message translates to:
  /// **'You were selected! 🎉'**
  String get notif_type_selected_title;

  /// No description provided for @notif_type_selected_body.
  ///
  /// In en, this message translates to:
  /// **'You\'re going to the meetup'**
  String get notif_type_selected_body;

  /// No description provided for @notif_type_not_selected_title.
  ///
  /// In en, this message translates to:
  /// **'Not this time'**
  String get notif_type_not_selected_title;

  /// No description provided for @notif_type_not_selected_body.
  ///
  /// In en, this message translates to:
  /// **'Don\'t worry, keep going'**
  String get notif_type_not_selected_body;

  /// No description provided for @notif_type_new_message_title.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get notif_type_new_message_title;

  /// No description provided for @notif_type_new_message_body.
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String notif_type_new_message_body(String name);

  /// No description provided for @notif_type_selfie_approved_title.
  ///
  /// In en, this message translates to:
  /// **'Profile verified ✓'**
  String get notif_type_selfie_approved_title;

  /// No description provided for @notif_type_selfie_approved_body.
  ///
  /// In en, this message translates to:
  /// **'You can now join invitations'**
  String get notif_type_selfie_approved_body;

  /// No description provided for @notif_type_selfie_rejected_title.
  ///
  /// In en, this message translates to:
  /// **'Photo rejected'**
  String get notif_type_selfie_rejected_title;

  /// No description provided for @notif_type_selfie_rejected_body.
  ///
  /// In en, this message translates to:
  /// **'Please upload a new selfie'**
  String get notif_type_selfie_rejected_body;

  /// No description provided for @notif_type_meeting_reminder_title.
  ///
  /// In en, this message translates to:
  /// **'Meeting reminder'**
  String get notif_type_meeting_reminder_title;

  /// No description provided for @notif_type_meeting_reminder_body.
  ///
  /// In en, this message translates to:
  /// **'Your meetup is starting soon'**
  String get notif_type_meeting_reminder_body;

  /// No description provided for @notif_type_feedback_request_title.
  ///
  /// In en, this message translates to:
  /// **'How was the meetup?'**
  String get notif_type_feedback_request_title;

  /// No description provided for @notif_type_feedback_request_body.
  ///
  /// In en, this message translates to:
  /// **'Share your experience'**
  String get notif_type_feedback_request_body;

  /// No description provided for @notif_action_new_message.
  ///
  /// In en, this message translates to:
  /// **'sent a message'**
  String get notif_action_new_message;

  /// No description provided for @notif_type_new_application_body_noname.
  ///
  /// In en, this message translates to:
  /// **'You have a new application'**
  String get notif_type_new_application_body_noname;

  /// No description provided for @notif_type_new_message_body_noname.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notif_type_new_message_body_noname;

  /// No description provided for @notif_grouped_messages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} new message} other{{count} new messages}}'**
  String notif_grouped_messages(int count);

  /// No description provided for @notif_action_new_application.
  ///
  /// In en, this message translates to:
  /// **'applied to your invitation'**
  String get notif_action_new_application;

  /// No description provided for @notif_action_selected.
  ///
  /// In en, this message translates to:
  /// **'selected you 🎉'**
  String get notif_action_selected;

  /// No description provided for @notif_action_not_selected.
  ///
  /// In en, this message translates to:
  /// **'responded to your application'**
  String get notif_action_not_selected;

  /// No description provided for @chat_hide_conversation.
  ///
  /// In en, this message translates to:
  /// **'Hide chat'**
  String get chat_hide_conversation;

  /// No description provided for @chat_hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chat_hide;

  /// No description provided for @chat_block_and_close.
  ///
  /// In en, this message translates to:
  /// **'Block and Close'**
  String get chat_block_and_close;

  /// No description provided for @chat_block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chat_block;

  /// No description provided for @chat_open.
  ///
  /// In en, this message translates to:
  /// **'Chat open'**
  String get chat_open;

  /// No description provided for @chat_hide_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'This chat leaves your list. The other person still sees it; it returns when a new message arrives.'**
  String get chat_hide_confirm_body;

  /// No description provided for @chat_block_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block this person? The chat will close.'**
  String chat_block_confirm_body(String gender);

  /// No description provided for @error_page_not_found.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get error_page_not_found;

  /// No description provided for @error_with_detail.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error_with_detail(String error);

  /// No description provided for @create_inv_gate_title.
  ///
  /// In en, this message translates to:
  /// **'Selfie approval required'**
  String get create_inv_gate_title;

  /// No description provided for @create_inv_gate_none.
  ///
  /// In en, this message translates to:
  /// **'For safety, you need to upload a selfie before creating an invitation.'**
  String get create_inv_gate_none;

  /// No description provided for @create_inv_gate_pending.
  ///
  /// In en, this message translates to:
  /// **'Your selfie is being reviewed. Admins approve within 24 hours — you can create invitations after approval.'**
  String get create_inv_gate_pending;

  /// No description provided for @create_inv_gate_rejected.
  ///
  /// In en, this message translates to:
  /// **'Your selfie was rejected. Please upload a new one.'**
  String get create_inv_gate_rejected;

  /// No description provided for @create_inv_gate_action_upload.
  ///
  /// In en, this message translates to:
  /// **'Take selfie'**
  String get create_inv_gate_action_upload;

  /// No description provided for @create_inv_gate_action_ok.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get create_inv_gate_action_ok;

  /// No description provided for @create_inv_active_limit_title_invite.
  ///
  /// In en, this message translates to:
  /// **'You Already Have an Active Invitation'**
  String get create_inv_active_limit_title_invite;

  /// No description provided for @create_inv_active_limit_title_request.
  ///
  /// In en, this message translates to:
  /// **'You Already Have an Active Request'**
  String get create_inv_active_limit_title_request;

  /// No description provided for @create_inv_active_limit_body.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current one to expire or cancel it before creating a new one.'**
  String get create_inv_active_limit_body;

  /// No description provided for @create_inv_active_limit_cta_view.
  ///
  /// In en, this message translates to:
  /// **'View Current One'**
  String get create_inv_active_limit_cta_view;

  /// No description provided for @create_inv_active_limit_cta_ok.
  ///
  /// In en, this message translates to:
  /// **'Got It'**
  String get create_inv_active_limit_cta_ok;

  /// No description provided for @create_inv_error_active_limit.
  ///
  /// In en, this message translates to:
  /// **'You already have an active invitation or request, you can\'t create a new one.'**
  String get create_inv_error_active_limit;

  /// No description provided for @paywall_title.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used your free application'**
  String get paywall_title;

  /// No description provided for @paywall_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe for unlimited applications.'**
  String get paywall_subtitle;

  /// No description provided for @paywall_perk_unlimited_invitations.
  ///
  /// In en, this message translates to:
  /// **'Unlimited invitations'**
  String get paywall_perk_unlimited_invitations;

  /// No description provided for @paywall_perk_unlimited_applications.
  ///
  /// In en, this message translates to:
  /// **'Unlimited applications'**
  String get paywall_perk_unlimited_applications;

  /// No description provided for @paywall_perk_chat_after_match.
  ///
  /// In en, this message translates to:
  /// **'Chat after mutual selection'**
  String get paywall_perk_chat_after_match;

  /// No description provided for @paywall_perk_priority_moderation.
  ///
  /// In en, this message translates to:
  /// **'Priority moderation'**
  String get paywall_perk_priority_moderation;

  /// No description provided for @paywall_price.
  ///
  /// In en, this message translates to:
  /// **'1000₽ / month'**
  String get paywall_price;

  /// No description provided for @paywall_cta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywall_cta;

  /// No description provided for @paywall_cancel_anytime.
  ///
  /// In en, this message translates to:
  /// **'You can cancel any time.'**
  String get paywall_cancel_anytime;

  /// No description provided for @paywall_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Payment system coming soon — awaiting IP registration.'**
  String get paywall_coming_soon;

  /// No description provided for @paywall_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywall_close;

  /// No description provided for @profile_inv_section.
  ///
  /// In en, this message translates to:
  /// **'MY CARDS'**
  String get profile_inv_section;

  /// No description provided for @profile_inv_empty_title.
  ///
  /// In en, this message translates to:
  /// **'No active invitation'**
  String get profile_inv_empty_title;

  /// No description provided for @profile_inv_create_cta.
  ///
  /// In en, this message translates to:
  /// **'+ Create invitation'**
  String get profile_inv_create_cta;

  /// No description provided for @profile_inv_applicants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} applicant} other{{count} applicants}}'**
  String profile_inv_applicants(int count);

  /// No description provided for @profile_inv_expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get profile_inv_expired;

  /// No description provided for @profile_inv_hours_left.
  ///
  /// In en, this message translates to:
  /// **'{h}h left'**
  String profile_inv_hours_left(int h);

  /// No description provided for @profile_inv_minutes_left.
  ///
  /// In en, this message translates to:
  /// **'{m}m'**
  String profile_inv_minutes_left(int m);

  /// No description provided for @sub_title.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get sub_title;

  /// No description provided for @sub_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sub_status_active;

  /// No description provided for @sub_status_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sub_status_cancelled;

  /// No description provided for @sub_status_past_due.
  ///
  /// In en, this message translates to:
  /// **'Payment issue'**
  String get sub_status_past_due;

  /// No description provided for @sub_none_title.
  ///
  /// In en, this message translates to:
  /// **'No subscription yet'**
  String get sub_none_title;

  /// No description provided for @sub_none_body.
  ///
  /// In en, this message translates to:
  /// **'Get Premium with auto-renewal or a one-time 30-day pass.'**
  String get sub_none_body;

  /// No description provided for @sub_none_body_ios.
  ///
  /// In en, this message translates to:
  /// **'A subscription purchased on another platform will appear here.'**
  String get sub_none_body_ios;

  /// No description provided for @sub_get_premium.
  ///
  /// In en, this message translates to:
  /// **'Get Premium'**
  String get sub_get_premium;

  /// No description provided for @sub_next_charge.
  ///
  /// In en, this message translates to:
  /// **'Next charge'**
  String get sub_next_charge;

  /// No description provided for @sub_card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get sub_card;

  /// No description provided for @sub_price_label.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get sub_price_label;

  /// No description provided for @sub_premium_until.
  ///
  /// In en, this message translates to:
  /// **'Premium is active until {date}'**
  String sub_premium_until(String date);

  /// No description provided for @sub_cancel_button.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get sub_cancel_button;

  /// No description provided for @sub_cancel_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription?'**
  String get sub_cancel_confirm_title;

  /// No description provided for @sub_cancel_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal will be turned off. Premium stays active until {date}.'**
  String sub_cancel_confirm_body(String date);

  /// No description provided for @sub_cancel_confirm_yes.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get sub_cancel_confirm_yes;

  /// No description provided for @sub_cancel_confirm_no.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get sub_cancel_confirm_no;

  /// No description provided for @sub_cancelled_note.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled. Premium is active until {date}.'**
  String sub_cancelled_note(String date);

  /// No description provided for @sub_resume_button.
  ///
  /// In en, this message translates to:
  /// **'Continue with card •••• {last4}'**
  String sub_resume_button(String last4);

  /// No description provided for @sub_history_title.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get sub_history_title;

  /// No description provided for @sub_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email for receipts and notices'**
  String get sub_email_label;

  /// No description provided for @sub_consent.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Offer terms and authorize automatic charges of 1,000 ₽ every 30 days until I cancel'**
  String get sub_consent;

  /// No description provided for @sub_subscribe_cta.
  ///
  /// In en, this message translates to:
  /// **'Subscribe — 1000 ₽/month'**
  String get sub_subscribe_cta;

  /// No description provided for @sub_onetime_cta.
  ///
  /// In en, this message translates to:
  /// **'One-time 30 days — 1000 ₽'**
  String get sub_onetime_cta;

  /// No description provided for @sub_auto_renews.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically every 30 days. Cancel anytime.'**
  String get sub_auto_renews;

  /// No description provided for @sub_already_active.
  ///
  /// In en, this message translates to:
  /// **'You already have an active subscription.'**
  String get sub_already_active;

  /// No description provided for @sub_use_resume_hint.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is cancelled but the period is still active — resume it in Profile → Subscription.'**
  String get sub_use_resume_hint;

  /// No description provided for @sub_email_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get sub_email_invalid;

  /// No description provided for @sub_consent_required.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue.'**
  String get sub_consent_required;

  /// No description provided for @sub_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sub_continue;

  /// No description provided for @sub_retry_button.
  ///
  /// In en, this message translates to:
  /// **'Retry payment'**
  String get sub_retry_button;

  /// No description provided for @sub_retry_failed.
  ///
  /// In en, this message translates to:
  /// **'The charge failed. Check your card and try again later.'**
  String get sub_retry_failed;

  /// No description provided for @sub_retry_limit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts today — try again tomorrow.'**
  String get sub_retry_limit;

  /// No description provided for @sub_resumed_note.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal is on. Next charge — {date}.'**
  String sub_resumed_note(String date);

  /// No description provided for @sub_price_month.
  ///
  /// In en, this message translates to:
  /// **'{price} ₽ / month'**
  String sub_price_month(String price);

  /// No description provided for @profile_setup_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email (optional) — for receipts and news'**
  String get profile_setup_email_label;

  /// No description provided for @profile_setup_email_hint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get profile_setup_email_hint;

  /// No description provided for @profile_setup_marketing_consent.
  ///
  /// In en, this message translates to:
  /// **'I agree to receive SoulChoice news and special offers (including promotional) by email. You can withdraw consent at any time — in settings or by writing to support@soulchoice.app.'**
  String get profile_setup_marketing_consent;

  /// No description provided for @paywall_subtitle_ios.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocks unlimited access.'**
  String get paywall_subtitle_ios;
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
