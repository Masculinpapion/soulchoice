// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboarding_1_title =>
      'You have the plan. Now find someone to go with.';

  @override
  String get onboarding_1_desc =>
      'A restaurant, a concert, an event. Open an invitation, treat and choose who comes along.';

  @override
  String get onboarding_2_title =>
      'Say where you want to go, let someone invite you';

  @override
  String get onboarding_2_desc =>
      'A café, a theatre, a concert. Share your wish and wait for someone to treat and take you.';

  @override
  String get onboarding_3_title => 'Verified profiles, a responsible community';

  @override
  String get onboarding_3_desc =>
      'Every profile is verified with a selfie. Users who miss meetings or behave inappropriately are blocked.';

  @override
  String get onboarding_start_button => 'Start';

  @override
  String get onboarding_skip => 'Skip';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_discover => 'Discover';

  @override
  String get nav_messages => 'Messages';

  @override
  String get nav_profile => 'Profile';

  @override
  String get nav_notifications => 'Notifications';

  @override
  String get btn_continue => 'Continue';

  @override
  String get btn_cancel => 'Cancel';

  @override
  String get btn_save => 'Save';

  @override
  String get btn_delete => 'Delete';

  @override
  String get btn_confirm => 'Confirm';

  @override
  String get btn_reject => 'Reject';

  @override
  String get btn_try_again => 'Try again';

  @override
  String get empty_no_invitations => 'No active invitations yet';

  @override
  String get empty_no_messages => 'No messages yet';

  @override
  String get empty_no_notifications => 'No notifications yet';

  @override
  String get error_generic => 'Something went wrong';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_language_system => 'System language';

  @override
  String get settings_notifications => 'Notifications';

  @override
  String get settings_account => 'Account';

  @override
  String get settings_logout => 'Log out';

  @override
  String get settings_delete_account => 'Delete account';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_profile_section => 'PROFILE';

  @override
  String get settings_edit_profile => 'Edit profile';

  @override
  String get settings_edit_photos => 'Edit photos';

  @override
  String get settings_notification_prefs => 'Notification preferences';

  @override
  String get notif_pref_push_section => 'Push notifications';

  @override
  String get notif_pref_new_application => 'New applications';

  @override
  String get notif_pref_new_application_sub =>
      'Someone responded to your invitation';

  @override
  String get notif_pref_selected => 'You\'re selected';

  @override
  String get notif_pref_selected_sub =>
      'Your application was accepted — chat opens';

  @override
  String get notif_pref_message => 'Messages';

  @override
  String get notif_pref_message_sub => 'New messages in chats';

  @override
  String get notif_pref_match => 'Matches';

  @override
  String get notif_pref_match_sub => 'Mutual selection';

  @override
  String get notif_pref_saved => 'Settings saved';

  @override
  String get notif_pref_all_read => 'All notifications read';

  @override
  String get settings_do_not_disturb => 'Do not disturb';

  @override
  String get settings_active_devices => 'Active devices';

  @override
  String get settings_download_data => 'Download my data';

  @override
  String get phone_title => 'Enter your\nphone number';

  @override
  String get phone_subtitle => 'We will send you a verification code';

  @override
  String get phone_error_empty => 'Enter phone number';

  @override
  String get phone_error_connection => 'Connection error, please try again';

  @override
  String get phone_terms => 'By continuing you accept our';

  @override
  String get phone_terms_link_privacy => 'Privacy Policy';

  @override
  String get phone_terms_link_terms => 'Terms of Use';

  @override
  String get otp_title => 'Enter the code';

  @override
  String get otp_sent_to => 'Incoming call to ';

  @override
  String get otp_call_hint => 'Enter the last 4 digits of the incoming number';

  @override
  String get otp_sms_sent_to => 'SMS code sent to ';

  @override
  String get otp_sms_hint => 'Enter the 4-digit code from the message';

  @override
  String get otp_get_by_call => 'No SMS? Get the code by phone call';

  @override
  String otp_resend_countdown(int seconds) {
    return 'Resend (${seconds}s)';
  }

  @override
  String get otp_resend => 'Resend';

  @override
  String get otp_verify => 'Verify';

  @override
  String get otp_error_failed => 'Verification failed';

  @override
  String get perm_notification_title => 'Allow notifications';

  @override
  String get perm_notification_desc =>
      'Required to notify you of new messages when selected';

  @override
  String get perm_location_title => 'Share your location';

  @override
  String get perm_location_desc =>
      'We need your location to show nearby invitations';

  @override
  String get perm_photos_title => 'Access photo gallery';

  @override
  String get perm_photos_desc => 'Required to add photos to your profile';

  @override
  String get perm_grant => 'Allow';

  @override
  String get perm_not_now => 'Not now';

  @override
  String get perm_denied_hint =>
      'You can grant this permission from settings to use this feature';

  @override
  String get perm_go_to_settings => 'Go to settings';

  @override
  String get perm_camera_title => 'Allow camera access';

  @override
  String get perm_camera_desc =>
      'Required to take a selfie for identity verification';

  @override
  String get feed_all_cities => 'All Cities';

  @override
  String get feed_active_invitations => 'ACTIVE INVITATIONS';

  @override
  String get feed_active_requests => 'ACTIVE REQUESTS';

  @override
  String get feed_24h_badge => '24 HRS';

  @override
  String feed_error(String error) {
    return 'Error: $error';
  }

  @override
  String get feed_no_invitations => 'No invitations yet';

  @override
  String get feed_be_first => 'Be the first to open one!';

  @override
  String get feed_todays_invitations => 'TODAY\'S INVITATIONS';

  @override
  String get feed_todays_requests => 'TODAY\'S REQUESTS';

  @override
  String get feed_swipe_hint => '· SWIPE →';

  @override
  String get feed_cta_invite => 'I want to come';

  @override
  String get feed_cta_request => 'I want to join';

  @override
  String get feed_city_picker_title => 'Select City';

  @override
  String get feed_city_search_hint => 'Search city…';

  @override
  String feed_city_not_found(String query) {
    return 'No city found for \"$query\"';
  }

  @override
  String get feed_tab_invitations => 'Invitations';

  @override
  String get feed_tab_requests => 'Requests';

  @override
  String get feed_city_name_moscow => 'Moscow';

  @override
  String get discover_title => 'Discover';

  @override
  String get discover_all_invitations_label => 'ALL ACTIVE INVITATIONS';

  @override
  String get discover_filter_all => 'All';

  @override
  String get discover_empty_title => 'No active invitations yet';

  @override
  String get discover_empty_subtitle => 'Be the first to open one here';

  @override
  String get discover_btn_create => '+ Create Invitation';

  @override
  String get discover_error => 'Connection error';

  @override
  String get applicants_title => 'Applicants';

  @override
  String applicants_count(int count) {
    return '$count people';
  }

  @override
  String get applicants_empty => 'No applications yet';

  @override
  String get applicants_select_btn => 'Select';

  @override
  String get applicants_error_already_matched =>
      'This invitation is already matched';

  @override
  String get applicants_error_not_authorized => 'Authorization error';

  @override
  String applicants_error_generic(String message) {
    return 'Error: $message';
  }

  @override
  String get create_inv_step_flow_type => 'Invitation type';

  @override
  String get create_inv_step_category => 'Category';

  @override
  String get create_inv_step_title => 'Title';

  @override
  String get create_inv_step_description => 'Description';

  @override
  String get create_inv_step_venue => 'Venue';

  @override
  String get create_inv_step_datetime => 'Date & Time';

  @override
  String get create_inv_step_duration => 'Duration';

  @override
  String get create_inv_validation_category => 'Please select a category';

  @override
  String get create_inv_validation_title => 'Title cannot be empty';

  @override
  String get create_inv_validation_venue => 'Venue name cannot be empty';

  @override
  String get create_inv_validation_date => 'Please select a date and time';

  @override
  String create_inv_error_publish(String error) {
    return 'Error: $error';
  }

  @override
  String get create_inv_btn_next => 'Next';

  @override
  String get create_inv_btn_publish => 'Publish';

  @override
  String get create_inv_btn_update => 'Update';

  @override
  String get edit_inv_title => 'Edit invitation';

  @override
  String get create_inv_flow_invite_title => 'I\'m Hosting';

  @override
  String get create_inv_flow_invite_subtitle => '';

  @override
  String get create_inv_flow_request_title => 'Seeking Invite';

  @override
  String get create_inv_flow_request_subtitle => '';

  @override
  String get create_inv_flow_question => 'What do you want to open?';

  @override
  String get create_inv_category_question => 'What experience are you sharing?';

  @override
  String get create_inv_title_subtitle =>
      'Short and catchy — will appear large in the feed';

  @override
  String get create_inv_title_label => 'Title';

  @override
  String get create_inv_desc_invite_hint => 'Where are you going?';

  @override
  String get create_inv_desc_request_hint => 'Where do you want to go?';

  @override
  String get create_inv_desc_input_hint => 'Write the details...';

  @override
  String get create_inv_venue_question => 'Where?';

  @override
  String get create_inv_venue_subtitle =>
      'Short venue name — café, restaurant, park';

  @override
  String get create_inv_venue_label => 'Venue name';

  @override
  String get create_inv_venue_placeholder =>
      'E.g. Cafe Pushkin, Strelka Bar...';

  @override
  String get create_inv_duration_question => 'Validity period';

  @override
  String get create_inv_duration_subtitle =>
      'After this time the invitation disappears from the feed';

  @override
  String get create_inv_duration_6h => '6 hours';

  @override
  String get create_inv_duration_6h_desc => 'Short-term — for today';

  @override
  String get create_inv_duration_12h => '12 hours';

  @override
  String get create_inv_duration_12h_desc => 'Half a day';

  @override
  String get create_inv_duration_24h => '24 hours';

  @override
  String get create_inv_duration_24h_desc => 'Standard — 1 day';

  @override
  String get create_inv_duration_48h => '48 hours';

  @override
  String get create_inv_duration_48h_desc => 'Long-term — 2 days';

  @override
  String get create_inv_datetime_question => 'When?';

  @override
  String get create_inv_datetime_subtitle => 'Select the event date and time';

  @override
  String get create_inv_venue_ph_food => 'Restaurant name';

  @override
  String get create_inv_venue_ph_bar => 'Bar name';

  @override
  String get create_inv_venue_ph_coffee => 'Café name';

  @override
  String get create_inv_venue_ph_sport => 'Court or club name';

  @override
  String get create_inv_venue_ph_walk => 'Park or meeting spot';

  @override
  String get create_inv_venue_ph_karaoke => 'Karaoke bar name';

  @override
  String get create_inv_venue_ph_cinema => 'Cinema name';

  @override
  String get create_inv_venue_ph_theater => 'Theatre name';

  @override
  String get create_inv_venue_ph_concert => 'Venue name';

  @override
  String get create_inv_venue_ph_culture => 'Venue name';

  @override
  String get create_inv_venue_ph_travel => 'City or country';

  @override
  String get create_inv_venue_ph_gift => 'Where shall we meet?';

  @override
  String get create_inv_validation_description_travel =>
      'Please write where you want to go';

  @override
  String get create_inv_venue_question_gift_invite =>
      'Where would you like to hand over the gift?';

  @override
  String get create_inv_venue_question_gift_request =>
      'Where would you like to receive the gift?';

  @override
  String get create_inv_gift_url_label => 'Product link or name (optional)';

  @override
  String get create_inv_gift_url_hint =>
      'Link (goldapple, ozon…) or product name';

  @override
  String get create_inv_gift_url_helper =>
      'Only the person you pick sees it · after moderation';

  @override
  String get create_inv_gift_url_invalid =>
      'Known stores only: goldapple, wildberries, ozon, market.yandex, lamoda, letoile';

  @override
  String get create_inv_venue_subtitle_gift =>
      'The meeting point where you\'ll hand over the gift';

  @override
  String get create_inv_venue_subtitle_gift_request =>
      'The meeting point where you\'ll receive the gift';

  @override
  String get create_inv_venue_question_cinema => 'Which cinema?';

  @override
  String get create_inv_venue_subtitle_cinema =>
      'The cinema where you\'ll watch the movie';

  @override
  String get create_inv_venue_question_theater => 'Which theatre?';

  @override
  String get create_inv_venue_subtitle_theater =>
      'The theatre where the play will take place';

  @override
  String get create_inv_venue_question_concert => 'Which venue?';

  @override
  String get create_inv_venue_subtitle_concert =>
      'The venue where the event will take place';

  @override
  String get create_inv_desc_invite_food => 'Where are you going?';

  @override
  String get create_inv_desc_invite_bar => 'Where are you going?';

  @override
  String get create_inv_desc_invite_coffee => 'Where are you going?';

  @override
  String get create_inv_desc_invite_cinema => 'Film title?';

  @override
  String get create_inv_desc_invite_theater => 'Play title?';

  @override
  String get create_inv_desc_invite_concert => 'Event name?';

  @override
  String get create_inv_desc_invite_culture => 'Where are you going?';

  @override
  String get create_inv_desc_invite_travel => 'Where are you going?';

  @override
  String get create_inv_desc_invite_gift => 'What would you like to give?';

  @override
  String get create_inv_desc_request_food => 'Where do you want to go?';

  @override
  String get create_inv_desc_request_bar => 'Where do you want to go?';

  @override
  String get create_inv_desc_request_coffee => 'Where do you want to go?';

  @override
  String get create_inv_desc_request_cinema => 'Which film do you want to see?';

  @override
  String get create_inv_desc_request_theater =>
      'Which play do you want to see?';

  @override
  String get create_inv_desc_request_concert =>
      'Which event do you want to attend?';

  @override
  String get create_inv_desc_request_culture => 'Where do you want to go?';

  @override
  String get create_inv_desc_request_travel => 'Where do you want to go?';

  @override
  String get create_inv_desc_invite_sport => 'What\'s the activity?';

  @override
  String get create_inv_desc_request_sport => 'What would you like to do?';

  @override
  String get create_inv_desc_invite_walk => 'Where are you walking?';

  @override
  String get create_inv_desc_request_walk => 'Where would you like to walk?';

  @override
  String get create_inv_desc_invite_karaoke => 'Where are you singing?';

  @override
  String get create_inv_desc_request_karaoke => 'Where would you like to sing?';

  @override
  String get create_inv_desc_request_gift => 'What would you like to receive?';

  @override
  String get create_inv_title_ph_food => 'e.g. Dinner at an Italian restaurant';

  @override
  String get create_inv_title_ph_bar => 'e.g. Cocktails at a rooftop bar';

  @override
  String get create_inv_title_ph_coffee => 'e.g. Afternoon coffee break';

  @override
  String get create_inv_title_ph_cinema => 'e.g. New sci-fi movie night';

  @override
  String get create_inv_title_ph_theater => 'e.g. A classic play night';

  @override
  String get create_inv_title_ph_concert => 'e.g. Live concert on Friday';

  @override
  String get create_inv_title_ph_culture => 'e.g. Modern art exhibition';

  @override
  String get create_inv_title_ph_travel =>
      'e.g. Weekend getaway to St. Petersburg';

  @override
  String get create_inv_title_ph_gift => 'e.g. A little surprise for you';

  @override
  String get create_inv_title_ph_sport => 'e.g. Weekend tennis match';

  @override
  String get create_inv_title_ph_walk => 'e.g. Sunset walk by the water';

  @override
  String get create_inv_title_ph_karaoke =>
      'e.g. Karaoke night — up for a duet?';

  @override
  String get create_inv_desc_ph_food =>
      'e.g. A cozy Italian place — pasta, wine and good conversation. I\'ll book the table.';

  @override
  String get create_inv_desc_ph_bar =>
      'e.g. A bar with a city view, cocktails and good music. First drink\'s on me.';

  @override
  String get create_inv_desc_ph_coffee =>
      'e.g. A cozy café — filter coffee, dessert and easy conversation.';

  @override
  String get create_inv_desc_ph_cinema =>
      'e.g. Evening screening of the new release, then coffee to talk it over. Tickets on me.';

  @override
  String get create_inv_desc_ph_theater =>
      'e.g. A classic performance, then a short walk and conversation after.';

  @override
  String get create_inv_desc_ph_concert =>
      'e.g. My favourite band live — great energy, great music. I\'ll sort the tickets.';

  @override
  String get create_inv_desc_ph_culture =>
      'e.g. Let\'s walk through the new exhibition, then share impressions at the museum café.';

  @override
  String get create_inv_desc_ph_travel =>
      'e.g. Two days in the city — old town, a river cruise and good food. Itinerary\'s ready.';

  @override
  String get create_inv_desc_ph_gift =>
      'e.g. A special gift I think you\'ll love — handed over with a coffee.';

  @override
  String get create_inv_desc_ph_sport =>
      'e.g. An hour of tennis on an indoor court, smoothies after. I have a spare racket.';

  @override
  String get create_inv_desc_ph_walk =>
      'e.g. An easy evening walk in the park — fresh air, nice views, good talk.';

  @override
  String get create_inv_desc_ph_karaoke =>
      'e.g. A fun karaoke night — any repertoire, no shyness allowed.';

  @override
  String get create_inv_venue_subtitle_travel =>
      'The city or country you\'re heading to';

  @override
  String get create_inv_venue_subtitle_sport => 'Court, gym or club name';

  @override
  String get create_inv_desc_ph_food_req =>
      'e.g. Dreaming of a cozy Italian dinner — pasta, wine and easy conversation.';

  @override
  String get create_inv_desc_ph_bar_req =>
      'e.g. I\'d love to meet over cocktails at a bar with a city view and good music.';

  @override
  String get create_inv_desc_ph_coffee_req =>
      'e.g. Up for a good chat over coffee and dessert at a cozy café.';

  @override
  String get create_inv_desc_ph_cinema_req =>
      'e.g. I\'d love to catch the new release on the big screen and talk it over after.';

  @override
  String get create_inv_desc_ph_theater_req =>
      'e.g. I\'ve been meaning to see a classic play — with a walk and chat after.';

  @override
  String get create_inv_desc_ph_concert_req =>
      'e.g. I love live music energy — looking for company for a good concert.';

  @override
  String get create_inv_desc_ph_culture_req =>
      'e.g. I\'d like to wander the new exhibition and share impressions at the museum café.';

  @override
  String get create_inv_desc_ph_travel_req =>
      'e.g. Dreaming of a two-day city escape — old town, a river cruise and good food.';

  @override
  String get create_inv_desc_ph_gift_req =>
      'e.g. I adore little surprises — anyone who enjoys spoiling someone?';

  @override
  String get create_inv_desc_ph_sport_req =>
      'e.g. Looking for a tennis partner — an hour of play, smoothies after.';

  @override
  String get create_inv_desc_ph_walk_req =>
      'e.g. An easy evening walk in the park and good conversation sounds perfect.';

  @override
  String get create_inv_desc_ph_karaoke_req =>
      'e.g. Looking for karaoke company — happy to duet or just cheer along.';

  @override
  String get create_inv_title_ph_gift_req => 'e.g. I love surprises';

  @override
  String get create_inv_datetime_placeholder => 'Select date & time';

  @override
  String get decision_selected_title => 'Match Confirmation';

  @override
  String decision_selected_body(String name, String title) {
    return 'You selected $name for your \"$title\" invitation.\nWould you like to confirm this match?';
  }

  @override
  String get decision_time_remaining => 'time remaining';

  @override
  String get decision_time_expired => 'Time expired';

  @override
  String get decision_accept => 'Yes, confirm';

  @override
  String get decision_reject => 'No, cancel';

  @override
  String get decision_fallback_name => 'Person';

  @override
  String decision_error(String error) {
    return 'Error: $error';
  }

  @override
  String get inv_detail_not_found => 'Invitation not found';

  @override
  String get inv_detail_delete_title => 'Delete invitation';

  @override
  String inv_detail_delete_body(String gender) {
    return 'Are you sure you want to delete this invitation? This cannot be undone.';
  }

  @override
  String get inv_detail_delete_cancel => 'Cancel';

  @override
  String get inv_detail_delete_confirm => 'Delete';

  @override
  String get inv_detail_status_closed => 'This invitation is closed';

  @override
  String get inv_detail_status_meeting => 'Meeting';

  @override
  String get inv_detail_status_decision => 'DECISION TIME';

  @override
  String get inv_detail_status_selecting => 'SELECTION WINDOW';

  @override
  String get inv_detail_status_awaiting => 'AWAITING SELECTION';

  @override
  String get inv_detail_status_remaining => 'TIME REMAINING';

  @override
  String get inv_detail_status_expired => 'Expired';

  @override
  String get inv_detail_status_not_selected => 'Not selected';

  @override
  String get inv_detail_day_mon => 'Mon';

  @override
  String get inv_detail_day_tue => 'Tue';

  @override
  String get inv_detail_day_wed => 'Wed';

  @override
  String get inv_detail_day_thu => 'Thu';

  @override
  String get inv_detail_day_fri => 'Fri';

  @override
  String get inv_detail_day_sat => 'Sat';

  @override
  String get inv_detail_day_sun => 'Sun';

  @override
  String get inv_detail_directions => 'Directions';

  @override
  String get inv_detail_section_invitation => 'INVITATION';

  @override
  String get inv_detail_section_details => 'DETAILS';

  @override
  String get inv_detail_section_host => 'HOST';

  @override
  String get inv_detail_host_label => 'Invitation host';

  @override
  String get inv_detail_section_with_whom => 'WITH';

  @override
  String get inv_detail_section_who => 'WHO';

  @override
  String get inv_detail_applicants_btn => 'View Applicants';

  @override
  String get inv_detail_loading => 'Loading...';

  @override
  String get inv_detail_error_label => 'Error';

  @override
  String get inv_detail_apply_invite => 'I want to come';

  @override
  String get inv_detail_apply_request => 'I want to join';

  @override
  String get inv_detail_apply_sending => 'Sending...';

  @override
  String get inv_detail_withdraw_title => 'Withdraw application';

  @override
  String inv_detail_withdraw_body(String gender) {
    return 'Are you sure you want to withdraw your application for this invitation?';
  }

  @override
  String get inv_detail_withdraw_cancel => 'Cancel';

  @override
  String get inv_detail_withdraw_confirm => 'Withdraw';

  @override
  String get inv_detail_withdraw_btn => 'Withdraw Application';

  @override
  String get inv_detail_withdrawing => 'Cancelling...';

  @override
  String get inv_detail_selected_btn => 'Selected — Make your decision';

  @override
  String get inv_detail_accepted_btn => '✓ Accepted';

  @override
  String get inv_detail_apply_sent_title => 'Application Sent';

  @override
  String get inv_detail_apply_sent_body =>
      'Wait for the invitation owner to make their choice';

  @override
  String inv_detail_error(String error) {
    return 'Error: $error';
  }

  @override
  String get inv_detail_retry => 'Retry';

  @override
  String inv_detail_duration_days_hours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String inv_detail_duration_hours_min(int hours, int min) {
    return '${hours}h ${min}m';
  }

  @override
  String inv_detail_duration_min(int min) {
    return '${min}m';
  }

  @override
  String get inv_detail_weekday_mon_full => 'Monday';

  @override
  String get inv_detail_weekday_tue_full => 'Tuesday';

  @override
  String get inv_detail_weekday_wed_full => 'Wednesday';

  @override
  String get inv_detail_weekday_thu_full => 'Thursday';

  @override
  String get inv_detail_weekday_fri_full => 'Friday';

  @override
  String get inv_detail_weekday_sat_full => 'Saturday';

  @override
  String get inv_detail_weekday_sun_full => 'Sunday';

  @override
  String get chat_deleted_user => 'Deleted user';

  @override
  String get chat_gift_link_label => 'Gift item — view';

  @override
  String get chat_gift_text_label => 'Gift item';

  @override
  String get chat_gift_disclaimer =>
      'This purchase happens outside SoulChoice, in a third-party store; users are responsible.';

  @override
  String get notif_selected_push_title => 'You\'re selected! 🎉';

  @override
  String get notif_selected_push_body => 'Chat is open — say hello';

  @override
  String get chat_deleted_user_info =>
      'This user deleted their account. You can no longer send messages.';

  @override
  String get chat_meeting_question => 'Did your meeting happen?';

  @override
  String get chat_yes_we_met => 'Yes, we met';

  @override
  String get chat_other_no_show => 'The other person didn\'t come';

  @override
  String chat_send_error(String error) {
    return 'Could not send: $error';
  }

  @override
  String get chat_meeting_saved => 'Thanks! Meeting recorded.';

  @override
  String get chat_noted => 'Noted.';

  @override
  String chat_other_age(int age) {
    return '$age years old';
  }

  @override
  String get chat_empty_hint => 'Be the first to send a message!';

  @override
  String get chat_input_hint => 'Write a message...';

  @override
  String get messages_title => 'Messages';

  @override
  String get messages_tab_active => 'Active';

  @override
  String get messages_tab_past => 'Past';

  @override
  String get messages_connection_error => 'Connection error';

  @override
  String get messages_no_preview => 'No messages yet';

  @override
  String get messages_new_match => 'New match ✨';

  @override
  String chat_selected_welcome(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'other': '$name chose you — you can now chat 🎉',
    });
    return '$_temp0';
  }

  @override
  String get profile_view_cta_message => 'Send a message';

  @override
  String get phone_session_expired =>
      'Your session has expired — please sign in again.';

  @override
  String get suspended_title => 'Account suspended';

  @override
  String get suspended_body =>
      'Your account has been suspended due to repeated no-shows or a rule violation. If you believe this is a mistake, contact us.';

  @override
  String get suspended_contact => 'Contact support';

  @override
  String get suspended_logout => 'Sign out';

  @override
  String get err_selfie_required =>
      'Verify your profile with a selfie first — opening the camera screen.';

  @override
  String get err_apply_limit =>
      'Your free application is used — Premium unlocks unlimited applications.';

  @override
  String get err_invitation_closed =>
      'This invitation is no longer accepting applications.';

  @override
  String get err_active_invitation_limit =>
      'You already have an active invitation of this type.';

  @override
  String get err_account_suspended => 'Your account is suspended.';

  @override
  String get selfie_reason_face_unclear => 'Face not clearly visible';

  @override
  String get selfie_reason_too_far => 'Take a closer selfie';

  @override
  String get selfie_reason_accessories => 'Glasses/hat/mask cover your face';

  @override
  String get selfie_reason_lighting => 'Poor lighting — retake in good light';

  @override
  String get selfie_reason_mismatch => 'Doesn\'t match your profile photos';

  @override
  String get selfie_reason_multiple_people =>
      'Someone else in frame — take it alone';

  @override
  String get profile_my_applications => 'My applications';

  @override
  String get app_status_pending => 'PENDING';

  @override
  String get app_status_accepted => 'ACCEPTED';

  @override
  String get app_status_rejected => 'NOT SELECTED';

  @override
  String get app_status_expired => 'NO SELECTION';

  @override
  String get paywall_premium_active => 'Premium is active — enjoy! 🎉';

  @override
  String get notif_type_selection_reminder_title =>
      'Applications are waiting ✨';

  @override
  String get notif_type_selection_reminder_body =>
      'Your selection window closes soon — take a look at your applicants.';

  @override
  String get messages_empty_past => 'No past chats';

  @override
  String get messages_empty_active => 'No chats yet';

  @override
  String get messages_empty_hint =>
      'Open an invitation or apply to an existing one';

  @override
  String get messages_btn_create => 'Create Invitation';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get notifications_mark_all_read => 'Mark all read';

  @override
  String notifications_error(String error) {
    return 'Error: $error';
  }

  @override
  String get notifications_empty => 'No notifications yet';

  @override
  String get photo_upload_title_edit => 'Edit your photos';

  @override
  String get photo_upload_title_add => 'Add your photos';

  @override
  String photo_upload_subtitle(int min, int max, int filled, int total) {
    return 'Min $min max $max photos • $filled / $total';
  }

  @override
  String get photo_upload_primary_label => 'Primary photo';

  @override
  String get photo_upload_primary_badge => 'Main';

  @override
  String get photo_upload_permission_error =>
      'Gallery permission required. Please allow from settings.';

  @override
  String photo_upload_pick_error(String error) {
    return 'Could not pick photo: $error';
  }

  @override
  String photo_upload_error(String error) {
    return 'Upload error: $error';
  }

  @override
  String get photo_upload_btn_save => 'Save';

  @override
  String get photo_upload_btn_continue => 'Continue';

  @override
  String get photo_crop_title => 'Edit photo';

  @override
  String get photo_crop_apply => 'Apply';

  @override
  String photo_crop_error(String error) {
    return 'Crop error: $error';
  }

  @override
  String get profile_setup_step_name_age => 'Name & age';

  @override
  String get profile_setup_step_gender => 'Gender';

  @override
  String get profile_setup_step_city => 'City';

  @override
  String get profile_setup_step_bio => 'Bio';

  @override
  String get profile_setup_step_job_edu => 'Work / Education';

  @override
  String get profile_setup_step_interests => 'Interests';

  @override
  String get profile_setup_step_prompts => 'Questions';

  @override
  String get profile_setup_step_age_range => 'Age range';

  @override
  String get profile_setup_step_consent => 'Consent';

  @override
  String get profile_setup_consent_subtitle =>
      'Before continuing, please confirm the three items below.';

  @override
  String get profile_setup_consent_age => 'I am 18 years of age or older';

  @override
  String get profile_setup_consent_data =>
      'I consent to the processing of my personal data in accordance with the';

  @override
  String get profile_setup_consent_data_link => 'Privacy Policy';

  @override
  String get profile_setup_consent_visibility =>
      'I allow my profile (photo, name, age, city) to be shown to other users of the service';

  @override
  String get profile_setup_validation_gender => 'Please select a gender';

  @override
  String get profile_setup_validation_city => 'Please select a city';

  @override
  String get profile_setup_validation_name => 'Name cannot be empty';

  @override
  String profile_setup_validation_age(int min, int max) {
    return 'Age must be between $min and $max';
  }

  @override
  String profile_setup_error(String error) {
    return 'Error: $error';
  }

  @override
  String get profile_setup_btn_next => 'Next';

  @override
  String get profile_setup_btn_add_photos => 'Add photos';

  @override
  String get profile_setup_name_question => 'What\'s your name?';

  @override
  String get profile_setup_name_label => 'Name';

  @override
  String profile_setup_age_label(int min, int max) {
    return 'Age ($min-$max)';
  }

  @override
  String get profile_setup_gender_title => 'Gender';

  @override
  String get profile_setup_gender_female => 'Female';

  @override
  String get profile_setup_gender_male => 'Male';

  @override
  String get profile_setup_city_question => 'What city are you in?';

  @override
  String get profile_setup_city_search => 'Search city...';

  @override
  String get profile_setup_city_not_found => 'City not found';

  @override
  String get profile_setup_bio_title => 'Tell us about yourself';

  @override
  String get profile_setup_bio_subtitle => 'Optional — max 200 characters';

  @override
  String get profile_setup_bio_hint => 'Briefly introduce yourself...';

  @override
  String get profile_setup_job_title => 'Work & Education';

  @override
  String get profile_setup_job_subtitle => 'Optional';

  @override
  String get profile_setup_job_label => 'Occupation';

  @override
  String get profile_setup_education_label => 'School / University';

  @override
  String get profile_setup_interests_title => 'Interests';

  @override
  String get profile_setup_interests_subtitle => 'Select at least 3';

  @override
  String get profile_setup_prompts_title => 'A few questions';

  @override
  String get profile_setup_prompts_subtitle =>
      'Optional — enriches your profile';

  @override
  String get profile_setup_prompts_answer_hint => 'Your answer...';

  @override
  String get profile_setup_age_range_title =>
      'What age range are you looking for?';

  @override
  String get profile_setup_age_range_subtitle =>
      'Only invitations in this age range will appear in your feed';

  @override
  String profile_setup_age_range_value(int min, int max) {
    return '$min — $max years';
  }

  @override
  String get profile_setup_prompt_favorite_restaurant =>
      'MY FAVOURITE RESTAURANT...';

  @override
  String profile_setup_prompt_last_book(String gender) {
    return 'THE LAST BOOK I READ...';
  }

  @override
  String get profile_setup_prompt_perfect_evening => 'A PERFECT EVENING...';

  @override
  String get profile_setup_prompt_travel_dream => 'MY DREAM TRIP...';

  @override
  String get profile_setup_interest_art => 'Art';

  @override
  String get profile_setup_interest_music => 'Music';

  @override
  String get profile_setup_interest_sports => 'Sports';

  @override
  String get profile_setup_interest_books => 'Books';

  @override
  String get profile_setup_interest_travel => 'Travel';

  @override
  String get profile_setup_interest_food => 'Food';

  @override
  String get profile_setup_interest_film => 'Film';

  @override
  String get profile_setup_interest_theatre => 'Theatre';

  @override
  String get profile_setup_interest_dance => 'Dance';

  @override
  String get profile_setup_interest_yoga => 'Yoga';

  @override
  String get profile_setup_interest_photography => 'Photography';

  @override
  String get profile_setup_interest_games => 'Games';

  @override
  String get profile_setup_interest_technology => 'Technology';

  @override
  String get profile_setup_interest_nature => 'Nature';

  @override
  String get profile_setup_interest_history => 'History';

  @override
  String get profile_setup_interest_fashion => 'Fashion';

  @override
  String get profile_view_not_found => 'Profile not found';

  @override
  String get profile_view_hint_name_age => 'Name and age missing';

  @override
  String get profile_view_hint_photo => 'Add a photo';

  @override
  String get profile_view_hint_bio => 'Add a bio';

  @override
  String get profile_view_hint_interests => 'Add interests';

  @override
  String get profile_view_hint_selfie_pending => 'Selfie under review...';

  @override
  String get profile_view_hint_selfie_upload => 'Upload selfie';

  @override
  String get profile_view_hint_prompt => 'Answer a question';

  @override
  String profile_view_completion(int score) {
    return '$score% complete';
  }

  @override
  String get profile_view_section_interests => 'INTERESTS';

  @override
  String get profile_view_section_prompts => 'EXPRESSIONS';

  @override
  String get profile_view_cta_edit => 'Edit Profile';

  @override
  String get profile_view_cta_come => 'I want to come';

  @override
  String get profile_view_action_block => 'Block user';

  @override
  String get profile_view_action_block_confirm => 'Block';

  @override
  String get profile_view_action_block_cancel => 'Cancel';

  @override
  String get profile_view_action_report => 'Report';

  @override
  String get profile_view_action_cancel => 'Cancel';

  @override
  String profile_view_blocked_snack(String name, String gender) {
    return '$name blocked';
  }

  @override
  String get profile_view_block_confirm_body =>
      'Are you sure you want to block this user?';

  @override
  String get profile_view_anonymous_user => 'User';

  @override
  String get report_title => 'Report user';

  @override
  String get report_why => 'Why are you reporting?';

  @override
  String get report_reason_inappropriate => 'Inappropriate content / photo';

  @override
  String get report_reason_harassment => 'Harassment or threats';

  @override
  String get report_reason_spam => 'Spam or fake account';

  @override
  String get report_reason_illegal => 'Illegal activity';

  @override
  String get report_reason_other => 'Other';

  @override
  String get report_desc_label => 'Description (optional)';

  @override
  String get report_desc_label_required => 'Description (required)';

  @override
  String get report_desc_hint => 'You can add more detail...';

  @override
  String get report_btn_sending => 'Sending...';

  @override
  String get report_btn_submit => 'Submit report';

  @override
  String get report_error_no_reason => 'Please select a reason';

  @override
  String get report_error_desc_required =>
      'Please add a description for \"Other\"';

  @override
  String get report_success =>
      'Your report has been received, we will review it';

  @override
  String report_error(String error) {
    return 'Error: $error';
  }

  @override
  String get selfie_title => 'Selfie verification';

  @override
  String get selfie_subtitle =>
      'We manually verify your profile for a safe community';

  @override
  String get selfie_take_btn => 'Take selfie';

  @override
  String get selfie_tip_lighting => 'Take in a well-lit environment';

  @override
  String get selfie_tip_face => 'Your face should be clearly visible';

  @override
  String get selfie_tip_approval => 'A moderator approves within 24 hours';

  @override
  String get selfie_submit_btn => 'Submit';

  @override
  String get blocked_users_title => 'Blocked';

  @override
  String get blocked_users_empty => 'No blocked users';

  @override
  String get blocked_users_unblock_btn => 'Unblock';

  @override
  String get delete_account_title => 'Delete Account';

  @override
  String get delete_account_heading => 'This cannot be undone';

  @override
  String get delete_account_body =>
      'If you delete your account, all your data, messages, matches and photos will be permanently deleted. This cannot be undone.';

  @override
  String get delete_account_warn_profile =>
      'Your profile and all photos will be deleted';

  @override
  String get delete_account_warn_messages =>
      'Your entire message history will be deleted';

  @override
  String get delete_account_warn_invitations =>
      'Your active invitations and applications will be deleted';

  @override
  String get delete_account_warn_phone =>
      'You cannot re-register with the same phone number';

  @override
  String get delete_account_checkbox =>
      'Yes, I want to permanently delete my account';

  @override
  String get delete_account_btn_delete => 'Permanently Delete Account';

  @override
  String get delete_account_btn_cancel => 'Cancel';

  @override
  String get delete_account_success =>
      'Your account has been marked for deletion. It will be permanently removed shortly.';

  @override
  String get delete_account_error => 'An error occurred. Please try again.';

  @override
  String get settings_coming_soon => 'This feature is coming soon.';

  @override
  String get settings_ok => 'OK';

  @override
  String get settings_about_subtitle => 'Premium social invitation app.';

  @override
  String get settings_share_subject => 'SoulChoice Data Export';

  @override
  String settings_error(String error) {
    return 'Error: $error';
  }

  @override
  String get settings_quiet_hours_title => 'Night quiet hours';

  @override
  String get settings_quiet_active => 'Active';

  @override
  String get settings_quiet_start => 'Start';

  @override
  String get settings_quiet_end => 'End';

  @override
  String get settings_age_range_title => 'Age range';

  @override
  String settings_age_range_value(int min, int max) {
    return '$min — $max years';
  }

  @override
  String get settings_privacy_section => 'PRIVACY & SECURITY';

  @override
  String get settings_blocked_users => 'Blocked';

  @override
  String get settings_location_permission => 'Location permission';

  @override
  String get settings_camera_permission => 'Camera permission';

  @override
  String get settings_support_section => 'SUPPORT';

  @override
  String get settings_help => 'Help & Support';

  @override
  String get settings_about => 'About';

  @override
  String get settings_logout_error => 'Could not sign out. Please try again.';

  @override
  String get settings_selfie_pending => 'Selfie under review';

  @override
  String get settings_selfie_approved => 'Verified account';

  @override
  String get settings_selfie_rejected => 'Selfie rejected — re-upload';

  @override
  String get settings_selfie_none => 'No selfie uploaded yet';

  @override
  String get settings_verification_status => 'Verification status';

  @override
  String get settings_reupload => 'Re-upload';

  @override
  String get admin_title => 'Moderation';

  @override
  String get admin_tab_selfies => 'Selfie Reviews';

  @override
  String get admin_tab_reports => 'Reports';

  @override
  String get admin_reject_reason_title => 'Rejection reason';

  @override
  String get admin_reject_reason_no_face => 'Face not visible';

  @override
  String get admin_reject_reason_inappropriate => 'Inappropriate content';

  @override
  String get admin_reject_reason_mismatch =>
      'Different person (doesn\'t match profile photo)';

  @override
  String get admin_reject_reason_quality => 'Low quality / blurry';

  @override
  String get admin_reject_reason_other => 'Other';

  @override
  String get admin_btn_cancel => 'Cancel';

  @override
  String get admin_btn_reject => 'Reject';

  @override
  String get admin_selfies_empty => 'No pending selfies';

  @override
  String get admin_view_profile => 'View profile';

  @override
  String get admin_photo_label_profile => 'Profile Photo';

  @override
  String get admin_photo_label_selfie => 'Selfie';

  @override
  String get admin_btn_approve => '✅ Approve';

  @override
  String get admin_btn_reject_action => '❌ Reject';

  @override
  String get admin_reports_empty => 'No pending reports';

  @override
  String admin_report_about(String name) {
    return 'report about $name';
  }

  @override
  String admin_reporter_label(String name) {
    return 'Reporter: $name';
  }

  @override
  String admin_reason_label(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get admin_user_banned => 'User banned';

  @override
  String get admin_btn_ban => 'Ban';

  @override
  String get admin_btn_dismiss => 'Dismiss';

  @override
  String get category_food => 'Dining';

  @override
  String get category_concert => 'Concert';

  @override
  String get category_travel => 'Travel';

  @override
  String get category_culture => 'Culture';

  @override
  String get category_cinema => 'Cinema';

  @override
  String get category_theater => 'Theatre';

  @override
  String get category_coffee => 'Coffee';

  @override
  String get category_bar => 'Bar';

  @override
  String get category_gift => 'Gift';

  @override
  String get category_sport => 'Sport';

  @override
  String get category_walk => 'Walk';

  @override
  String get category_karaoke => 'Karaoke';

  @override
  String get notif_type_new_application_title => 'New Application';

  @override
  String notif_type_new_application_body(String name) {
    return '$name applied to your invitation';
  }

  @override
  String get notif_type_selected_title => 'You were selected! 🎉';

  @override
  String get notif_type_selected_body => 'You\'re going to the meetup';

  @override
  String get notif_type_not_selected_title => 'Not this time';

  @override
  String get notif_type_not_selected_body => 'Don\'t worry, keep going';

  @override
  String get notif_type_new_message_title => 'New Message';

  @override
  String notif_type_new_message_body(String name) {
    return 'Message from $name';
  }

  @override
  String get notif_type_selfie_approved_title => 'Profile verified ✓';

  @override
  String get notif_type_selfie_approved_body => 'You can now join invitations';

  @override
  String get notif_type_premium_activated_title => 'Premium active';

  @override
  String notif_type_premium_activated_body(String date) {
    return 'Your subscription has started — Premium is active until $date';
  }

  @override
  String get notif_type_premium_activated_body_nodate =>
      'Your subscription has started — Premium is active';

  @override
  String get notif_type_selfie_rejected_title => 'Photo rejected';

  @override
  String get notif_type_selfie_rejected_body => 'Please upload a new selfie';

  @override
  String get notif_type_meeting_reminder_title => 'Meeting reminder';

  @override
  String get notif_type_meeting_reminder_body => 'Your meetup is starting soon';

  @override
  String get notif_type_feedback_request_title => 'How was the meetup?';

  @override
  String get notif_type_feedback_request_body => 'Share your experience';

  @override
  String notif_action_new_message(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {'other': 'sent a message'});
    return '$_temp0';
  }

  @override
  String get notif_type_new_application_body_noname =>
      'You have a new application';

  @override
  String get notif_type_new_message_body_noname => 'New message';

  @override
  String notif_grouped_messages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '$count new message',
    );
    return '$_temp0';
  }

  @override
  String notif_action_new_application(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'other': 'applied to your invitation',
    });
    return '$_temp0';
  }

  @override
  String notif_action_selected(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {'other': 'selected you 🎉'});
    return '$_temp0';
  }

  @override
  String notif_action_not_selected(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'other': 'responded to your application',
    });
    return '$_temp0';
  }

  @override
  String get chat_hide_conversation => 'Hide chat';

  @override
  String get chat_hide => 'Hide';

  @override
  String get chat_block_and_close => 'Block and Close';

  @override
  String get chat_block => 'Block';

  @override
  String get chat_open => 'Chat open';

  @override
  String get chat_hide_confirm_body =>
      'This chat leaves your list. The other person still sees it; it returns when a new message arrives.';

  @override
  String chat_block_confirm_body(String gender) {
    return 'Are you sure you want to block this person? The chat will close.';
  }

  @override
  String get error_page_not_found => 'Page not found';

  @override
  String error_with_detail(String error) {
    return 'Error: $error';
  }

  @override
  String get create_inv_gate_title => 'Selfie approval required';

  @override
  String get create_inv_gate_none =>
      'For safety, you need to upload a selfie before creating an invitation.';

  @override
  String get create_inv_gate_pending =>
      'Your selfie is being reviewed. A moderator approves within 24 hours — you can create invitations after approval.';

  @override
  String get create_inv_gate_rejected =>
      'Your selfie was rejected. Please upload a new one.';

  @override
  String get create_inv_gate_action_upload => 'Take selfie';

  @override
  String get create_inv_gate_action_ok => 'Got it';

  @override
  String get create_inv_active_limit_title_invite =>
      'You Already Have an Active Invitation';

  @override
  String get create_inv_active_limit_title_request =>
      'You Already Have an Active Request';

  @override
  String get create_inv_active_limit_body =>
      'Wait for the current one to expire or cancel it before creating a new one.';

  @override
  String get create_inv_active_limit_cta_view => 'View Current One';

  @override
  String get create_inv_active_limit_cta_ok => 'Got It';

  @override
  String get create_inv_error_active_limit =>
      'You already have an active invitation or request, you can\'t create a new one.';

  @override
  String get paywall_title => 'You\'ve used your free application';

  @override
  String get paywall_subtitle => 'Subscribe for unlimited applications.';

  @override
  String get paywall_perk_unlimited_invitations => 'Unlimited invitations';

  @override
  String get paywall_perk_unlimited_applications => 'Unlimited applications';

  @override
  String get paywall_perk_chat_after_match => 'Chat after mutual selection';

  @override
  String get paywall_perk_priority_moderation => 'Priority moderation';

  @override
  String get paywall_price => '1000₽ / month';

  @override
  String get paywall_cta => 'Continue';

  @override
  String get paywall_cancel_anytime => 'You can cancel any time.';

  @override
  String get paywall_coming_soon =>
      'Payment system coming soon — awaiting IP registration.';

  @override
  String get paywall_close => 'Close';

  @override
  String get profile_inv_section => 'MY CARDS';

  @override
  String get profile_inv_empty_title => 'No active invitation';

  @override
  String get profile_inv_create_cta => '+ Create invitation';

  @override
  String profile_inv_applicants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applicants',
      one: '$count applicant',
    );
    return '$_temp0';
  }

  @override
  String get profile_inv_expired => 'Expired';

  @override
  String profile_inv_hours_left(int h) {
    return '${h}h left';
  }

  @override
  String profile_inv_minutes_left(int m) {
    return '${m}m';
  }

  @override
  String get sub_title => 'Subscription';

  @override
  String get sub_status_active => 'Active';

  @override
  String get sub_status_cancelled => 'Cancelled';

  @override
  String get sub_status_past_due => 'Payment issue';

  @override
  String get sub_none_title => 'No subscription yet';

  @override
  String get sub_none_body =>
      'Get Premium with auto-renewal or a one-time 30-day pass.';

  @override
  String get sub_none_body_ios =>
      'A subscription purchased on another platform will appear here.';

  @override
  String get sub_get_premium => 'Get Premium';

  @override
  String get sub_next_charge => 'Next charge';

  @override
  String get sub_card => 'Card';

  @override
  String get sub_price_label => 'Plan';

  @override
  String sub_premium_until(String date) {
    return 'Premium is active until $date';
  }

  @override
  String get sub_cancel_button => 'Cancel subscription';

  @override
  String get sub_cancel_confirm_title => 'Cancel subscription?';

  @override
  String sub_cancel_confirm_body(String date) {
    return 'Auto-renewal will be turned off. Premium stays active until $date.';
  }

  @override
  String get sub_cancel_confirm_yes => 'Cancel subscription';

  @override
  String get sub_cancel_confirm_no => 'Keep it';

  @override
  String sub_cancelled_note(String date) {
    return 'Subscription cancelled. Premium is active until $date.';
  }

  @override
  String sub_resume_button(String last4) {
    return 'Continue with card •••• $last4';
  }

  @override
  String get sub_history_title => 'Payments';

  @override
  String get sub_email_label => 'Email for receipts and notices';

  @override
  String get sub_consent =>
      'I agree to the Offer terms and authorize automatic charges of 1,000 ₽ every 30 days until I cancel';

  @override
  String get sub_subscribe_cta => 'Subscribe — 1000 ₽/month';

  @override
  String get sub_onetime_cta => 'One-time 30 days — 1000 ₽';

  @override
  String get sub_auto_renews =>
      'Renews automatically every 30 days. Cancel anytime.';

  @override
  String get sub_already_active => 'You already have an active subscription.';

  @override
  String get sub_use_resume_hint =>
      'Your subscription is cancelled but the period is still active — resume it in Profile → Subscription.';

  @override
  String get sub_email_invalid => 'Enter a valid email.';

  @override
  String get sub_consent_required => 'Please accept the terms to continue.';

  @override
  String get sub_continue => 'Continue';

  @override
  String get sub_retry_button => 'Retry payment';

  @override
  String get sub_retry_failed =>
      'The charge failed. Check your card and try again later.';

  @override
  String get sub_retry_limit => 'Too many attempts today — try again tomorrow.';

  @override
  String sub_resumed_note(String date) {
    return 'Auto-renewal is on. Next charge — $date.';
  }

  @override
  String sub_price_month(String price) {
    return '$price ₽ / month';
  }

  @override
  String get profile_setup_email_label =>
      'Email (optional) — for receipts and news';

  @override
  String get profile_setup_email_hint => 'you@example.com';

  @override
  String get profile_setup_marketing_consent =>
      'I agree to receive SoulChoice news and special offers (including promotional) by email. You can withdraw consent at any time — in settings or by writing to support@soulchoice.app.';

  @override
  String get paywall_subtitle_ios => 'Premium unlocks unlimited access.';
}
