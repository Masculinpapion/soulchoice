// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get onboarding_1_title =>
      'Planın hazır, eksik olan birlikte gidecek biri';

  @override
  String get onboarding_1_desc =>
      'Bir restoran, bir konser, bir etkinlik. Davet aç, ısmarla ve kiminle gitmek istediğini sen seç.';

  @override
  String get onboarding_2_title =>
      'Gitmek istediğin yeri söyle, biri seni davet etsin';

  @override
  String get onboarding_2_desc =>
      'Bir kafe, bir tiyatro, bir konser. İsteğini paylaş, ısmarlayıp seni götürecek birini bekle.';

  @override
  String get onboarding_3_title =>
      'Doğrulanmış profiller, sorumlu bir topluluk';

  @override
  String get onboarding_3_desc =>
      'Her profil selfie ile onaylanır. Randevuya gelmeyen veya uygunsuz davranan kullanıcılar engellenir.';

  @override
  String get onboarding_start_button => 'Başla';

  @override
  String get onboarding_skip => 'Atla';

  @override
  String get nav_home => 'Ana Sayfa';

  @override
  String get nav_discover => 'Keşfet';

  @override
  String get nav_messages => 'Mesajlar';

  @override
  String get nav_profile => 'Profil';

  @override
  String get nav_notifications => 'Bildirimler';

  @override
  String get btn_continue => 'Devam';

  @override
  String get btn_cancel => 'İptal';

  @override
  String get btn_save => 'Kaydet';

  @override
  String get btn_delete => 'Sil';

  @override
  String get btn_confirm => 'Onayla';

  @override
  String get btn_reject => 'Reddet';

  @override
  String get btn_try_again => 'Tekrar dene';

  @override
  String get empty_no_invitations => 'Henüz aktif davet yok';

  @override
  String get empty_no_messages => 'Henüz mesajın yok';

  @override
  String get empty_no_notifications => 'Henüz bildirimin yok';

  @override
  String get error_generic => 'Bir hata oluştu';

  @override
  String get settings_language => 'Dil';

  @override
  String get settings_language_system => 'Sistem dili';

  @override
  String get settings_notifications => 'Bildirimler';

  @override
  String get settings_account => 'Hesap';

  @override
  String get settings_logout => 'Çıkış yap';

  @override
  String get settings_delete_account => 'Hesabı sil';

  @override
  String get settings_title => 'Ayarlar';

  @override
  String get settings_profile_section => 'PROFİL';

  @override
  String get settings_edit_profile => 'Profili düzenle';

  @override
  String get settings_edit_photos => 'Fotoğrafları düzenle';

  @override
  String get settings_notification_prefs => 'Bildirim tercihleri';

  @override
  String get notif_pref_push_section => 'Push bildirimleri';

  @override
  String get notif_pref_new_application => 'Yeni başvurular';

  @override
  String get notif_pref_new_application_sub => 'Biri davetine başvurdu';

  @override
  String get notif_pref_selected => 'Seçildin';

  @override
  String get notif_pref_selected_sub =>
      'Başvurun kabul edildi — sohbet açılıyor';

  @override
  String get notif_pref_message => 'Mesajlar';

  @override
  String get notif_pref_message_sub => 'Sohbetlerde yeni mesajlar';

  @override
  String get notif_pref_match => 'Eşleşmeler';

  @override
  String get notif_pref_match_sub => 'Karşılıklı seçim';

  @override
  String get notif_pref_saved => 'Ayarlar kaydedildi';

  @override
  String get notif_pref_all_read => 'Tüm bildirimler okundu';

  @override
  String get settings_do_not_disturb => 'Gece sessizliği';

  @override
  String get settings_active_devices => 'Aktif cihazlar';

  @override
  String get settings_download_data => 'Verilerimi indir';

  @override
  String get phone_title => 'Telefon numaranı\ngir';

  @override
  String get phone_subtitle => 'Sana bir doğrulama kodu göndereceğiz';

  @override
  String get phone_error_empty => 'Telefon numarası gir';

  @override
  String get phone_error_connection => 'Bağlantı hatası, tekrar dene';

  @override
  String get phone_terms => 'Devam ederek kabul etmiş olursun:';

  @override
  String get phone_terms_link_privacy => 'Gizlilik Politikası';

  @override
  String get phone_terms_link_terms => 'Kullanım Koşulları';

  @override
  String get otp_title => 'Kodu gir';

  @override
  String get otp_sent_to => 'Gelen arama: ';

  @override
  String get otp_call_hint => 'Gelen numaranın son 4 hanesini gir';

  @override
  String otp_resend_countdown(int seconds) {
    return 'Tekrar gönder (${seconds}s)';
  }

  @override
  String get otp_resend => 'Tekrar gönder';

  @override
  String get otp_verify => 'Doğrula';

  @override
  String get otp_error_failed => 'Doğrulama başarısız';

  @override
  String get perm_notification_title => 'Bildirimlere izin ver';

  @override
  String get perm_notification_desc =>
      'Seçildiğinde yeni mesajları bildirebilmek için gerekli';

  @override
  String get perm_location_title => 'Konumunu paylaş';

  @override
  String get perm_location_desc =>
      'Yakındaki davetleri göstermek için konumuna ihtiyacımız var';

  @override
  String get perm_photos_title => 'Fotoğraf galerisine eriş';

  @override
  String get perm_photos_desc => 'Profiline fotoğraf eklemek için gerekli';

  @override
  String get perm_grant => 'İzin ver';

  @override
  String get perm_not_now => 'Şimdi değil';

  @override
  String get perm_denied_hint =>
      'Bu özelliği kullanmak için ayarlardan izin verebilirsin';

  @override
  String get perm_go_to_settings => 'Ayarlara git';

  @override
  String get perm_camera_title => 'Kameraya erişime izin ver';

  @override
  String get perm_camera_desc => 'Kimlik doğrulama için selfie çekmek gerekli';

  @override
  String get feed_all_cities => 'Tüm Şehirler';

  @override
  String get feed_active_invitations => 'AKTİF DAVETİYELER';

  @override
  String get feed_active_requests => 'AKTİF İSTEKLER';

  @override
  String get feed_24h_badge => '24 SAAT';

  @override
  String feed_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get feed_no_invitations => 'Henüz davetiye yok';

  @override
  String get feed_be_first => 'İlk davetiyeyi sen aç!';

  @override
  String get feed_todays_invitations => 'GÜNÜN DAVETİYELERİ';

  @override
  String get feed_todays_requests => 'GÜNÜN İSTEKLERİ';

  @override
  String get feed_swipe_hint => '· KAYDIR →';

  @override
  String get feed_cta_invite => 'Gelmek isterim';

  @override
  String get feed_cta_request => 'Katılmak isterim';

  @override
  String get feed_city_picker_title => 'Şehir Seç';

  @override
  String get feed_city_search_hint => 'Şehir ara…';

  @override
  String feed_city_not_found(String query) {
    return '\"$query\" için şehir bulunamadı';
  }

  @override
  String get feed_tab_invitations => 'Davetiyeler';

  @override
  String get feed_tab_requests => 'İstekler';

  @override
  String get feed_city_name_moscow => 'Moskova';

  @override
  String get discover_title => 'Keşfet';

  @override
  String get discover_all_invitations_label => 'TÜM AKTİF DAVETİYELER';

  @override
  String get discover_filter_all => 'Tümü';

  @override
  String get discover_empty_title => 'Henüz aktif davetiye yok';

  @override
  String get discover_empty_subtitle => 'İlk davetiyeyi sen aç';

  @override
  String get discover_btn_create => '+ Davetiye Oluştur';

  @override
  String get discover_error => 'Bağlantı hatası';

  @override
  String get applicants_title => 'Başvuranlar';

  @override
  String applicants_count(int count) {
    return '$count kişi';
  }

  @override
  String get applicants_empty => 'Henüz başvuru yok';

  @override
  String get applicants_select_btn => 'Seç';

  @override
  String get applicants_error_already_matched =>
      'Bu davetiye zaten eşleştirildi';

  @override
  String get applicants_error_not_authorized => 'Yetkilendirme hatası';

  @override
  String applicants_error_generic(String message) {
    return 'Hata: $message';
  }

  @override
  String get create_inv_step_flow_type => 'Davetiye türü';

  @override
  String get create_inv_step_category => 'Kategori';

  @override
  String get create_inv_step_title => 'Başlık';

  @override
  String get create_inv_step_description => 'Açıklama';

  @override
  String get create_inv_step_venue => 'Mekan';

  @override
  String get create_inv_step_datetime => 'Tarih ve Saat';

  @override
  String get create_inv_step_duration => 'Süre';

  @override
  String get create_inv_validation_category => 'Lütfen bir kategori seç';

  @override
  String get create_inv_validation_title => 'Başlık boş olamaz';

  @override
  String get create_inv_validation_venue => 'Mekan adı boş olamaz';

  @override
  String get create_inv_validation_date => 'Lütfen tarih ve saat seç';

  @override
  String create_inv_error_publish(String error) {
    return 'Hata: $error';
  }

  @override
  String get create_inv_btn_next => 'İleri';

  @override
  String get create_inv_btn_publish => 'Yayınla';

  @override
  String get create_inv_btn_update => 'Güncelle';

  @override
  String get edit_inv_title => 'Davetiyeyi düzenle';

  @override
  String get create_inv_flow_invite_title => 'Davet ediyorum';

  @override
  String get create_inv_flow_invite_subtitle => '';

  @override
  String get create_inv_flow_request_title => 'Davet bekliyorum';

  @override
  String get create_inv_flow_request_subtitle => '';

  @override
  String get create_inv_flow_question => 'Ne açmak istiyorsun?';

  @override
  String get create_inv_category_question => 'Hangi deneyimi paylaşıyorsun?';

  @override
  String get create_inv_title_subtitle =>
      'Kısa ve çarpıcı — akışta büyük görünür';

  @override
  String get create_inv_title_label => 'Başlık';

  @override
  String get create_inv_desc_invite_hint => 'Nereye gidiyorsun?';

  @override
  String get create_inv_desc_request_hint => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_input_hint => 'Detayları yaz...';

  @override
  String get create_inv_venue_question => 'Nerede?';

  @override
  String get create_inv_venue_subtitle =>
      'Kısa mekan adı — kafe, restoran, park';

  @override
  String get create_inv_venue_label => 'Mekan adı';

  @override
  String get create_inv_venue_placeholder =>
      'Örn. Kafe Pushkin, Strelka Bar...';

  @override
  String get create_inv_duration_question => 'Geçerlilik süresi';

  @override
  String get create_inv_duration_subtitle =>
      'Bu süreden sonra davetiye akıştan kaybolur';

  @override
  String get create_inv_duration_6h => '6 saat';

  @override
  String get create_inv_duration_6h_desc => 'Kısa vadeli — bugün için';

  @override
  String get create_inv_duration_12h => '12 saat';

  @override
  String get create_inv_duration_12h_desc => 'Yarım gün';

  @override
  String get create_inv_duration_24h => '24 saat';

  @override
  String get create_inv_duration_24h_desc => 'Standart — 1 gün';

  @override
  String get create_inv_duration_48h => '48 saat';

  @override
  String get create_inv_duration_48h_desc => 'Uzun vadeli — 2 gün';

  @override
  String get create_inv_datetime_question => 'Ne zaman?';

  @override
  String get create_inv_datetime_subtitle => 'Etkinlik tarih ve saatini seç';

  @override
  String get create_inv_venue_ph_food => 'Restoran adı';

  @override
  String get create_inv_venue_ph_bar => 'Bar adı';

  @override
  String get create_inv_venue_ph_coffee => 'Kafe adı';

  @override
  String get create_inv_venue_ph_sport => 'Kort veya kulüp adı';

  @override
  String get create_inv_venue_ph_walk => 'Park veya buluşma yeri';

  @override
  String get create_inv_venue_ph_karaoke => 'Karaoke bar adı';

  @override
  String get create_inv_venue_ph_cinema => 'Sinema adı';

  @override
  String get create_inv_venue_ph_theater => 'Tiyatro adı';

  @override
  String get create_inv_venue_ph_concert => 'Mekan adı';

  @override
  String get create_inv_venue_ph_culture => 'Mekan adı';

  @override
  String get create_inv_venue_ph_travel => 'Şehir veya ülke';

  @override
  String get create_inv_venue_ph_gift => 'Nerede buluşalım?';

  @override
  String get create_inv_validation_description_travel =>
      'Nereye gitmek istediğini yazmalısın';

  @override
  String get create_inv_venue_question_gift =>
      'Hediyeni nerede buluşup teslim almak istersin?';

  @override
  String get create_inv_gift_url_label => 'Ürün linki (isteğe bağlı)';

  @override
  String get create_inv_gift_url_hint => 'goldapple, wildberries, ozon…';

  @override
  String get create_inv_gift_url_helper =>
      'Yalnızca seçtiğin kişi görür · moderasyon onayından sonra';

  @override
  String get create_inv_gift_url_invalid =>
      'Yalnız tanınan mağaza linkleri: goldapple, wildberries, ozon, market.yandex, lamoda, letoile';

  @override
  String get create_inv_venue_subtitle_gift =>
      'Hediyeni teslim edeceğin buluşma noktası';

  @override
  String get create_inv_venue_subtitle_gift_request =>
      'Hediyeni teslim alacağın buluşma noktası';

  @override
  String get create_inv_venue_question_cinema => 'Hangi sinemada?';

  @override
  String get create_inv_venue_subtitle_cinema =>
      'Filmi izleyeceğiniz sinema salonu';

  @override
  String get create_inv_venue_question_theater => 'Hangi tiyatroda?';

  @override
  String get create_inv_venue_subtitle_theater => 'Oyunu izleyeceğiniz tiyatro';

  @override
  String get create_inv_venue_question_concert => 'Hangi mekanda?';

  @override
  String get create_inv_venue_subtitle_concert => 'Etkinliğin yapılacağı mekan';

  @override
  String get create_inv_desc_invite_food => 'Nereye gidiyorsun?';

  @override
  String get create_inv_desc_invite_bar => 'Nereye gidiyorsun?';

  @override
  String get create_inv_desc_invite_coffee => 'Nereye gidiyorsun?';

  @override
  String get create_inv_desc_invite_cinema => 'Film adı?';

  @override
  String get create_inv_desc_invite_theater => 'Oyun adı?';

  @override
  String get create_inv_desc_invite_concert => 'Etkinlik adı?';

  @override
  String get create_inv_desc_invite_culture => 'Nereye gidiyorsun?';

  @override
  String get create_inv_desc_invite_travel => 'Nereye gidiyorsunuz?';

  @override
  String get create_inv_desc_invite_gift => 'Ne hediye etmek istiyorsun?';

  @override
  String get create_inv_desc_request_food => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_request_bar => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_request_coffee => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_request_cinema =>
      'Hangi filmi izlemek istiyorsun?';

  @override
  String get create_inv_desc_request_theater =>
      'Hangi oyunu görmek istiyorsun?';

  @override
  String get create_inv_desc_request_concert =>
      'Hangi etkinliğe gitmek istiyorsun?';

  @override
  String get create_inv_desc_request_culture => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_request_travel => 'Nereye gitmek istiyorsun?';

  @override
  String get create_inv_desc_invite_sport => 'Hangi aktivite?';

  @override
  String get create_inv_desc_request_sport => 'Ne yapmak istersin?';

  @override
  String get create_inv_desc_invite_walk => 'Nerede yürüyorsun?';

  @override
  String get create_inv_desc_request_walk => 'Nerede yürümek istersin?';

  @override
  String get create_inv_desc_invite_karaoke => 'Nerede şarkı söylüyorsun?';

  @override
  String get create_inv_desc_request_karaoke =>
      'Nerede şarkı söylemek istersin?';

  @override
  String get create_inv_desc_request_gift => 'Ne hediye edilmesini istiyorsun?';

  @override
  String get create_inv_datetime_placeholder => 'Tarih ve saat seç';

  @override
  String get decision_selected_title => 'Eşleşme Onayı';

  @override
  String decision_selected_body(String name, String title) {
    return '$name adlı kişiyi \"$title\" davetiyeniz için seçtiniz.\nBu eşleşmeyi onaylamak ister misiniz?';
  }

  @override
  String get decision_time_remaining => 'kalan süre';

  @override
  String get decision_time_expired => 'Süre doldu';

  @override
  String get decision_accept => 'Evet, onaylıyorum';

  @override
  String get decision_reject => 'Hayır, vazgeçiyorum';

  @override
  String get decision_fallback_name => 'Kişi';

  @override
  String decision_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get inv_detail_not_found => 'Davetiye bulunamadı';

  @override
  String get inv_detail_delete_title => 'Davetiyeyi sil';

  @override
  String inv_detail_delete_body(String gender) {
    return 'Bu davetiyeyi silmek istediğinden emin misin? Bu işlem geri alınamaz.';
  }

  @override
  String get inv_detail_delete_cancel => 'İptal';

  @override
  String get inv_detail_delete_confirm => 'Sil';

  @override
  String get inv_detail_status_closed => 'Bu davetiye kapatıldı';

  @override
  String get inv_detail_status_meeting => 'Buluşma';

  @override
  String get inv_detail_status_decision => 'KARAR VAKTİ';

  @override
  String get inv_detail_status_selecting => 'SEÇİM PENCERESİ';

  @override
  String get inv_detail_status_awaiting => 'SEÇİM BEKLENİYOR';

  @override
  String get inv_detail_status_remaining => 'KALAN SÜRE';

  @override
  String get inv_detail_status_expired => 'Süresi doldu';

  @override
  String get inv_detail_status_not_selected => 'Seçim yapılmadı';

  @override
  String get inv_detail_day_mon => 'Pzt';

  @override
  String get inv_detail_day_tue => 'Sal';

  @override
  String get inv_detail_day_wed => 'Çar';

  @override
  String get inv_detail_day_thu => 'Per';

  @override
  String get inv_detail_day_fri => 'Cum';

  @override
  String get inv_detail_day_sat => 'Cmt';

  @override
  String get inv_detail_day_sun => 'Paz';

  @override
  String get inv_detail_directions => 'Yol tarifi';

  @override
  String get inv_detail_section_invitation => 'DAVETİYE';

  @override
  String get inv_detail_section_details => 'DETAYLAR';

  @override
  String get inv_detail_section_host => 'DAVETÇI';

  @override
  String get inv_detail_host_label => 'Davetiye sahibi';

  @override
  String get inv_detail_section_with_whom => 'KİMİNLE';

  @override
  String get inv_detail_section_who => 'KİM';

  @override
  String get inv_detail_applicants_btn => 'Başvuranları Gör';

  @override
  String get inv_detail_loading => 'Yükleniyor...';

  @override
  String get inv_detail_error_label => 'Hata';

  @override
  String get inv_detail_apply_invite => 'Gelmek isterim';

  @override
  String get inv_detail_apply_request => 'Katılmak isterim';

  @override
  String get inv_detail_apply_sending => 'Gönderiliyor...';

  @override
  String get inv_detail_withdraw_title => 'Başvuruyu geri çek';

  @override
  String inv_detail_withdraw_body(String gender) {
    return 'Bu davetiye için başvurunu geri çekmek istediğinden emin misin?';
  }

  @override
  String get inv_detail_withdraw_cancel => 'İptal';

  @override
  String get inv_detail_withdraw_confirm => 'Geri çek';

  @override
  String get inv_detail_withdraw_btn => 'Başvuruyu Geri Çek';

  @override
  String get inv_detail_withdrawing => 'İptal ediliyor...';

  @override
  String get inv_detail_selected_btn => 'Seçildiniz — Kararınızı verin';

  @override
  String get inv_detail_accepted_btn => '✓ Kabul edildi';

  @override
  String get inv_detail_apply_sent_title => 'Başvuru Gönderildi';

  @override
  String get inv_detail_apply_sent_body =>
      'Davetiye sahibinin seçim yapmasını bekle';

  @override
  String inv_detail_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get inv_detail_retry => 'Tekrar dene';

  @override
  String inv_detail_duration_days_hours(int days, int hours) {
    return '${days}g ${hours}s';
  }

  @override
  String inv_detail_duration_hours_min(int hours, int min) {
    return '${hours}s ${min}d';
  }

  @override
  String inv_detail_duration_min(int min) {
    return '${min}d';
  }

  @override
  String get inv_detail_weekday_mon_full => 'Pazartesi';

  @override
  String get inv_detail_weekday_tue_full => 'Salı';

  @override
  String get inv_detail_weekday_wed_full => 'Çarşamba';

  @override
  String get inv_detail_weekday_thu_full => 'Perşembe';

  @override
  String get inv_detail_weekday_fri_full => 'Cuma';

  @override
  String get inv_detail_weekday_sat_full => 'Cumartesi';

  @override
  String get inv_detail_weekday_sun_full => 'Pazar';

  @override
  String get chat_archived => 'Bu sohbet arşivlendi';

  @override
  String get chat_deleted_user => 'Silinmiş kullanıcı';

  @override
  String get chat_gift_link_label => 'Hediye ürünü — görüntüle';

  @override
  String get chat_gift_disclaimer =>
      'Bu alışveriş SoulChoice dışında, üçüncü taraf mağazada gerçekleşir; sorumluluk kullanıcılara aittir.';

  @override
  String get notif_selected_push_title => 'Seçildin! 🎉';

  @override
  String get notif_selected_push_body => 'Sohbet açıldı — tanışmaya başla';

  @override
  String get chat_deleted_user_info =>
      'Bu kullanıcı hesabını sildi. Artık mesaj gönderemezsin.';

  @override
  String get chat_meeting_question => 'Buluşmanız gerçekleşti mi?';

  @override
  String get chat_yes_we_met => 'Evet, buluştuk';

  @override
  String get chat_other_no_show => 'Karşı taraf gelmedi';

  @override
  String chat_send_error(String error) {
    return 'Gönderilemedi: $error';
  }

  @override
  String get chat_meeting_saved => 'Teşekkürler! Buluşma kaydedildi.';

  @override
  String get chat_noted => 'Tamam.';

  @override
  String chat_other_age(int age) {
    return '$age yaşında';
  }

  @override
  String get chat_empty_hint => 'İlk mesajı gönder!';

  @override
  String get chat_input_hint => 'Mesaj yaz...';

  @override
  String get messages_title => 'Mesajlar';

  @override
  String get messages_tab_active => 'Aktif';

  @override
  String get messages_tab_past => 'Geçmiş';

  @override
  String get messages_connection_error => 'Bağlantı hatası';

  @override
  String get messages_no_preview => 'Henüz mesaj yok';

  @override
  String get messages_empty_past => 'Geçmiş sohbet yok';

  @override
  String get messages_empty_active => 'Henüz aktif sohbet yok';

  @override
  String get messages_empty_hint => 'Davetiye aç veya mevcut birine başvur';

  @override
  String get messages_btn_create => 'Davetiye Oluştur';

  @override
  String get notifications_title => 'Bildirimler';

  @override
  String get notifications_mark_all_read => 'Tümünü oku';

  @override
  String notifications_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get notifications_empty => 'Henüz bildirim yok';

  @override
  String get photo_upload_title_edit => 'Fotoğraflarını düzenle';

  @override
  String get photo_upload_title_add => 'Fotoğraflarını ekle';

  @override
  String photo_upload_subtitle(int min, int max, int filled, int total) {
    return 'Min $min maks $max fotoğraf • $filled / $total';
  }

  @override
  String get photo_upload_primary_label => 'Ana fotoğraf';

  @override
  String get photo_upload_primary_badge => 'Ana';

  @override
  String get photo_upload_permission_error =>
      'Galeri izni gerekli. Lütfen ayarlardan izin ver.';

  @override
  String photo_upload_pick_error(String error) {
    return 'Fotoğraf seçilemedi: $error';
  }

  @override
  String photo_upload_error(String error) {
    return 'Yükleme hatası: $error';
  }

  @override
  String get photo_upload_btn_save => 'Kaydet';

  @override
  String get photo_upload_btn_continue => 'Devam';

  @override
  String get photo_crop_title => 'Fotoğrafı düzenle';

  @override
  String get photo_crop_apply => 'Uygula';

  @override
  String photo_crop_error(String error) {
    return 'Kırpma hatası: $error';
  }

  @override
  String get profile_setup_step_name_age => 'İsim ve yaş';

  @override
  String get profile_setup_step_gender => 'Cinsiyet';

  @override
  String get profile_setup_step_city => 'Şehir';

  @override
  String get profile_setup_step_bio => 'Hakkımda';

  @override
  String get profile_setup_step_job_edu => 'Meslek / Eğitim';

  @override
  String get profile_setup_step_interests => 'İlgi alanları';

  @override
  String get profile_setup_step_prompts => 'Sorular';

  @override
  String get profile_setup_step_age_range => 'Yaş aralığı';

  @override
  String get profile_setup_step_consent => 'Onaylar';

  @override
  String get profile_setup_consent_subtitle =>
      'Devam etmeden önce aşağıdaki üç maddeyi onayla.';

  @override
  String get profile_setup_consent_age => '18 yaşımı doldurdum';

  @override
  String get profile_setup_consent_data =>
      'Kişisel verilerimin aşağıdaki metne uygun şekilde işlenmesine onay veriyorum:';

  @override
  String get profile_setup_consent_data_link => 'Gizlilik Politikası';

  @override
  String get profile_setup_consent_visibility =>
      'Profilimin (fotoğraf, isim, yaş, şehir) servisin diğer kullanıcılarına gösterilmesine izin veriyorum';

  @override
  String get profile_setup_validation_gender => 'Cinsiyet seçimi zorunludur';

  @override
  String get profile_setup_validation_city => 'Şehir seçimi zorunludur';

  @override
  String get profile_setup_validation_name => 'İsim boş olamaz';

  @override
  String profile_setup_validation_age(int min, int max) {
    return 'Yaş $min ile $max arasında olmalı';
  }

  @override
  String profile_setup_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get profile_setup_btn_next => 'İleri';

  @override
  String get profile_setup_btn_add_photos => 'Fotoğraf ekle';

  @override
  String get profile_setup_name_question => 'Adın ne?';

  @override
  String get profile_setup_name_label => 'İsim';

  @override
  String profile_setup_age_label(int min, int max) {
    return 'Yaş ($min-$max)';
  }

  @override
  String get profile_setup_gender_title => 'Cinsiyet';

  @override
  String get profile_setup_gender_female => 'Kadın';

  @override
  String get profile_setup_gender_male => 'Erkek';

  @override
  String get profile_setup_city_question => 'Hangi şehirdesin?';

  @override
  String get profile_setup_city_search => 'Şehir ara...';

  @override
  String get profile_setup_city_not_found => 'Şehir bulunamadı';

  @override
  String get profile_setup_bio_title => 'Kendin hakkında anlat';

  @override
  String get profile_setup_bio_subtitle => 'İsteğe bağlı — maks 200 karakter';

  @override
  String get profile_setup_bio_hint => 'Kendini kısaca tanıt...';

  @override
  String get profile_setup_job_title => 'Meslek ve Eğitim';

  @override
  String get profile_setup_job_subtitle => 'İsteğe bağlı';

  @override
  String get profile_setup_job_label => 'Meslek';

  @override
  String get profile_setup_education_label => 'Okul / Üniversite';

  @override
  String get profile_setup_interests_title => 'İlgi alanları';

  @override
  String get profile_setup_interests_subtitle => 'En az 3 seç';

  @override
  String get profile_setup_prompts_title => 'Birkaç soru';

  @override
  String get profile_setup_prompts_subtitle =>
      'İsteğe bağlı — profilini zenginleştirir';

  @override
  String get profile_setup_prompts_answer_hint => 'Cevabın...';

  @override
  String get profile_setup_age_range_title => 'Hangi yaş aralığını arıyorsun?';

  @override
  String get profile_setup_age_range_subtitle =>
      'Bu yaş aralığındaki davetiyeler akışında görünür';

  @override
  String profile_setup_age_range_value(int min, int max) {
    return '$min — $max yaş';
  }

  @override
  String get profile_setup_prompt_favorite_restaurant =>
      'EN SEVDİĞİM RESTORAN...';

  @override
  String profile_setup_prompt_last_book(String gender) {
    return 'SON OKUDUĞUM KİTAP...';
  }

  @override
  String get profile_setup_prompt_perfect_evening => 'MÜKEMMEL BİR AKŞAM...';

  @override
  String get profile_setup_prompt_travel_dream => 'HAYALİNDEKİ SEYAHAT...';

  @override
  String get profile_setup_interest_art => 'Sanat';

  @override
  String get profile_setup_interest_music => 'Müzik';

  @override
  String get profile_setup_interest_sports => 'Spor';

  @override
  String get profile_setup_interest_books => 'Kitaplar';

  @override
  String get profile_setup_interest_travel => 'Seyahat';

  @override
  String get profile_setup_interest_food => 'Yemek';

  @override
  String get profile_setup_interest_film => 'Film';

  @override
  String get profile_setup_interest_theatre => 'Tiyatro';

  @override
  String get profile_setup_interest_dance => 'Dans';

  @override
  String get profile_setup_interest_yoga => 'Yoga';

  @override
  String get profile_setup_interest_photography => 'Fotoğrafçılık';

  @override
  String get profile_setup_interest_games => 'Oyunlar';

  @override
  String get profile_setup_interest_technology => 'Teknoloji';

  @override
  String get profile_setup_interest_nature => 'Doğa';

  @override
  String get profile_setup_interest_history => 'Tarih';

  @override
  String get profile_setup_interest_fashion => 'Moda';

  @override
  String get profile_view_not_found => 'Profil bulunamadı';

  @override
  String get profile_view_hint_name_age => 'İsim ve yaş eksik';

  @override
  String get profile_view_hint_photo => 'Fotoğraf ekle';

  @override
  String get profile_view_hint_bio => 'Hakkımda ekle';

  @override
  String get profile_view_hint_interests => 'İlgi alanları ekle';

  @override
  String get profile_view_hint_selfie_pending => 'Selfie inceleniyor...';

  @override
  String get profile_view_hint_selfie_upload => 'Selfie yükle';

  @override
  String get profile_view_hint_prompt => 'Bir soruyu cevapla';

  @override
  String profile_view_completion(int score) {
    return '%$score tamamlandı';
  }

  @override
  String get profile_view_section_interests => 'İLGİ ALANLARI';

  @override
  String get profile_view_section_prompts => 'İFADELER';

  @override
  String get profile_view_cta_edit => 'Profili Düzenle';

  @override
  String get profile_view_cta_come => 'Gelmek isterim';

  @override
  String get profile_view_action_block => 'Kullanıcıyı engelle';

  @override
  String get profile_view_action_block_confirm => 'Engelle';

  @override
  String get profile_view_action_block_cancel => 'İptal';

  @override
  String get profile_view_action_report => 'Şikayet et';

  @override
  String get profile_view_action_cancel => 'İptal';

  @override
  String profile_view_blocked_snack(String name, String gender) {
    return '$name engellendi';
  }

  @override
  String get profile_view_block_confirm_body =>
      'Bu kullanıcıyı engellemek istediğine emin misin?';

  @override
  String get profile_view_anonymous_user => 'Kullanıcı';

  @override
  String get report_title => 'Kullanıcıyı şikayet et';

  @override
  String get report_why => 'Neden şikayet ediyorsun?';

  @override
  String get report_reason_inappropriate => 'Uygunsuz içerik / fotoğraf';

  @override
  String get report_reason_harassment => 'Taciz veya tehdit';

  @override
  String get report_reason_spam => 'Spam veya sahte hesap';

  @override
  String get report_reason_illegal => 'Yasadışı faaliyet';

  @override
  String get report_reason_other => 'Diğer';

  @override
  String get report_desc_label => 'Açıklama (isteğe bağlı)';

  @override
  String get report_desc_label_required => 'Açıklama (zorunlu)';

  @override
  String get report_desc_hint => 'Daha fazla detay ekleyebilirsin...';

  @override
  String get report_btn_sending => 'Gönderiliyor...';

  @override
  String get report_btn_submit => 'Şikayeti gönder';

  @override
  String get report_error_no_reason => 'Lütfen bir neden seç';

  @override
  String get report_error_desc_required => '\"Diğer\" için açıklama yazmalısın';

  @override
  String get report_success => 'Şikayetin alındı, inceleyeceğiz';

  @override
  String report_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get selfie_title => 'Selfie doğrulaması';

  @override
  String get selfie_subtitle =>
      'Güvenli bir topluluk için profilini manuel olarak doğruluyoruz';

  @override
  String get selfie_take_btn => 'Selfie çek';

  @override
  String get selfie_tip_lighting => 'İyi aydınlatılmış bir ortamda çek';

  @override
  String get selfie_tip_face => 'Yüzün açıkça görünmeli';

  @override
  String get selfie_tip_approval => 'Yönetici 24 saat içinde onaylar';

  @override
  String get selfie_submit_btn => 'Gönder';

  @override
  String get blocked_users_title => 'Engellenenler';

  @override
  String get blocked_users_empty => 'Engellenen kullanıcı yok';

  @override
  String get blocked_users_unblock_btn => 'Engeli kaldır';

  @override
  String get delete_account_title => 'Hesabı Sil';

  @override
  String get delete_account_heading => 'Bu işlem geri alınamaz';

  @override
  String get delete_account_body =>
      'Hesabını silersen tüm veriler, mesajlar, eşleşmeler ve fotoğraflar kalıcı olarak silinir. Bu işlem geri alınamaz.';

  @override
  String get delete_account_warn_profile =>
      'Profilin ve tüm fotoğrafların silinecek';

  @override
  String get delete_account_warn_messages => 'Tüm mesaj geçmişin silinecek';

  @override
  String get delete_account_warn_invitations =>
      'Aktif davetiyeler ve başvurular silinecek';

  @override
  String get delete_account_warn_phone =>
      'Aynı telefon numarasıyla yeniden kayıt olamazsın';

  @override
  String get delete_account_checkbox =>
      'Evet, hesabımı kalıcı olarak silmek istiyorum';

  @override
  String get delete_account_btn_delete => 'Hesabı Kalıcı Olarak Sil';

  @override
  String get delete_account_btn_cancel => 'İptal';

  @override
  String get delete_account_success =>
      'Hesabın silinmek üzere işaretlendi. Kısa süre içinde kalıcı olarak kaldırılacak.';

  @override
  String get delete_account_error => 'Bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get settings_coming_soon => 'Bu özellik yakında geliyor.';

  @override
  String get settings_ok => 'Tamam';

  @override
  String get settings_about_subtitle => 'Premium sosyal davetiye uygulaması.';

  @override
  String get settings_share_subject => 'SoulChoice Veri Dışa Aktarma';

  @override
  String settings_error(String error) {
    return 'Hata: $error';
  }

  @override
  String get settings_quiet_hours_title => 'Gece sessizliği';

  @override
  String get settings_quiet_active => 'Aktif';

  @override
  String get settings_quiet_start => 'Başlangıç';

  @override
  String get settings_quiet_end => 'Bitiş';

  @override
  String get settings_age_range_title => 'Yaş aralığı';

  @override
  String settings_age_range_value(int min, int max) {
    return '$min — $max yaş';
  }

  @override
  String get settings_privacy_section => 'GİZLİLİK VE GÜVENLİK';

  @override
  String get settings_blocked_users => 'Engellenenler';

  @override
  String get settings_location_permission => 'Konum izni';

  @override
  String get settings_camera_permission => 'Kamera izni';

  @override
  String get settings_support_section => 'DESTEK';

  @override
  String get settings_help => 'Yardım ve Destek';

  @override
  String get settings_about => 'Hakkında';

  @override
  String get settings_logout_error => 'Çıkış yapılamadı. Lütfen tekrar dene.';

  @override
  String get settings_selfie_pending => 'Selfie inceleniyor';

  @override
  String get settings_selfie_approved => 'Doğrulanmış hesap';

  @override
  String get settings_selfie_rejected => 'Selfie reddedildi — yeniden yükle';

  @override
  String get settings_selfie_none => 'Henüz selfie yüklenmedi';

  @override
  String get settings_verification_status => 'Doğrulama durumu';

  @override
  String get settings_reupload => 'Yeniden yükle';

  @override
  String get admin_title => 'Moderasyon';

  @override
  String get admin_tab_selfies => 'Selfie İncelemeleri';

  @override
  String get admin_tab_reports => 'Şikayetler';

  @override
  String get admin_reject_reason_title => 'Ret nedeni';

  @override
  String get admin_reject_reason_no_face => 'Yüz görünmüyor';

  @override
  String get admin_reject_reason_inappropriate => 'Uygunsuz içerik';

  @override
  String get admin_reject_reason_mismatch =>
      'Farklı kişi (profil fotoğrafıyla eşleşmiyor)';

  @override
  String get admin_reject_reason_quality => 'Düşük kalite / bulanık';

  @override
  String get admin_reject_reason_other => 'Diğer';

  @override
  String get admin_btn_cancel => 'İptal';

  @override
  String get admin_btn_reject => 'Reddet';

  @override
  String get admin_selfies_empty => 'Bekleyen selfie yok';

  @override
  String get admin_view_profile => 'Profili görüntüle';

  @override
  String get admin_photo_label_profile => 'Profil Fotoğrafı';

  @override
  String get admin_photo_label_selfie => 'Selfie';

  @override
  String get admin_btn_approve => '✅ Onayla';

  @override
  String get admin_btn_reject_action => '❌ Reddet';

  @override
  String get admin_reports_empty => 'Bekleyen şikayet yok';

  @override
  String admin_report_about(String name) {
    return '$name hakkında şikayet';
  }

  @override
  String admin_reporter_label(String name) {
    return 'Şikayet eden: $name';
  }

  @override
  String admin_reason_label(String reason) {
    return 'Neden: $reason';
  }

  @override
  String get admin_user_banned => 'Kullanıcı yasaklandı';

  @override
  String get admin_btn_ban => 'Yasakla';

  @override
  String get admin_btn_dismiss => 'Kapat';

  @override
  String get category_food => 'Restoran';

  @override
  String get category_concert => 'Konser';

  @override
  String get category_travel => 'Seyahat';

  @override
  String get category_culture => 'Kültür';

  @override
  String get category_cinema => 'Sinema';

  @override
  String get category_theater => 'Tiyatro';

  @override
  String get category_coffee => 'Kahve';

  @override
  String get category_bar => 'Bar';

  @override
  String get category_gift => 'Hediye';

  @override
  String get category_sport => 'Spor';

  @override
  String get category_walk => 'Yürüyüş';

  @override
  String get category_karaoke => 'Karaoke';

  @override
  String get notif_type_new_application_title => 'Yeni Başvuru';

  @override
  String notif_type_new_application_body(String name) {
    return '$name davetinize başvurdu';
  }

  @override
  String get notif_type_selected_title => 'Seçildin! 🎉';

  @override
  String get notif_type_selected_body => 'Buluşmaya gidiyorsun';

  @override
  String get notif_type_not_selected_title => 'Bu sefer olmadı';

  @override
  String get notif_type_not_selected_body => 'Üzülme, devam et';

  @override
  String get notif_type_new_message_title => 'Yeni Mesaj';

  @override
  String notif_type_new_message_body(String name) {
    return '$name mesaj gönderdi';
  }

  @override
  String get notif_type_selfie_approved_title => 'Profil onaylandı ✓';

  @override
  String get notif_type_selfie_approved_body =>
      'Artık davetlere katılabilirsin';

  @override
  String get notif_type_selfie_rejected_title => 'Fotoğraf reddedildi';

  @override
  String get notif_type_selfie_rejected_body => 'Lütfen yeni bir selfie yükle';

  @override
  String get notif_type_meeting_reminder_title => 'Buluşma hatırlatması';

  @override
  String get notif_type_meeting_reminder_body => 'Buluşman yakında başlıyor';

  @override
  String get notif_type_feedback_request_title => 'Buluşma nasıldı?';

  @override
  String get notif_type_feedback_request_body => 'Deneyimini paylaş';

  @override
  String get notif_action_new_message => 'mesaj gönderdi';

  @override
  String get notif_type_new_application_body_noname => 'Yeni bir başvuru geldi';

  @override
  String get notif_type_new_message_body_noname => 'Yeni mesaj';

  @override
  String notif_grouped_messages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yeni mesaj',
    );
    return '$_temp0';
  }

  @override
  String get notif_action_new_application => 'davetinize başvurdu';

  @override
  String get notif_action_selected => 'seni seçti 🎉';

  @override
  String get notif_action_not_selected => 'başvurunu yanıtladı';

  @override
  String get chat_hide_conversation => 'Sohbeti Gizle';

  @override
  String get chat_hide => 'Gizle';

  @override
  String get chat_block_and_close => 'Engelle ve Kapat';

  @override
  String get chat_block => 'Engelle';

  @override
  String get chat_open => 'Chat açık';

  @override
  String get chat_hide_confirm_body =>
      'Bu sohbet listenden kalkacak. Karşı taraf sohbeti görmeye devam eder; yeni mesaj gelirse sohbet geri gelir.';

  @override
  String chat_block_confirm_body(String gender) {
    return 'Bu kişiyi engellemek istediğine emin misin? Chat kapanacak.';
  }

  @override
  String get error_page_not_found => 'Sayfa bulunamadı';

  @override
  String error_with_detail(String error) {
    return 'Hata: $error';
  }

  @override
  String get create_inv_gate_title => 'Önce selfie onayı';

  @override
  String get create_inv_gate_none =>
      'Güvenlik için davetiye açmadan önce selfie yüklemen gerekiyor.';

  @override
  String get create_inv_gate_pending =>
      'Selfie\'n inceleniyor. Yönetici 24 saat içinde onaylar — onaydan sonra davetiye açabilirsin.';

  @override
  String get create_inv_gate_rejected =>
      'Selfie\'n reddedildi. Yeni bir selfie yüklemen gerekiyor.';

  @override
  String get create_inv_gate_action_upload => 'Selfie çek';

  @override
  String get create_inv_gate_action_ok => 'Anladım';

  @override
  String get create_inv_active_limit_title_invite =>
      'Zaten Aktif Bir Davetiyen Var';

  @override
  String get create_inv_active_limit_title_request =>
      'Zaten Aktif Bir İsteğin Var';

  @override
  String get create_inv_active_limit_body =>
      'Yenisini oluşturmadan önce mevcut olanın süresi dolmalı ya da onu iptal etmelisin.';

  @override
  String get create_inv_active_limit_cta_view => 'Mevcut Olanı Gör';

  @override
  String get create_inv_active_limit_cta_ok => 'Tamam';

  @override
  String get create_inv_error_active_limit =>
      'Zaten aktif bir davetiyen/isteğin var, yenisini oluşturamazsın.';

  @override
  String get paywall_title => 'Ücretsiz başvuru hakkını kullandın';

  @override
  String get paywall_subtitle => 'Sınırsız başvuru için aboneliği başlat.';

  @override
  String get paywall_perk_unlimited_invitations => 'Sınırsız davetiye';

  @override
  String get paywall_perk_unlimited_applications => 'Sınırsız başvuru';

  @override
  String get paywall_perk_chat_after_match =>
      'Karşılıklı seçimden sonra sohbet';

  @override
  String get paywall_perk_priority_moderation => 'Öncelikli moderasyon';

  @override
  String get paywall_price => '1000₽ / ay';

  @override
  String get paywall_cta => 'Devam et';

  @override
  String get paywall_cancel_anytime => 'İstediğin zaman iptal edebilirsin.';

  @override
  String get paywall_coming_soon =>
      'Ödeme sistemi yakında — ИП kuruluşu bekleniyor.';

  @override
  String get paywall_close => 'Kapat';

  @override
  String get profile_inv_section => 'KARTLARIM';

  @override
  String get profile_inv_empty_title => 'Henüz aktif davetin yok';

  @override
  String get profile_inv_create_cta => '+ Yeni davetiye oluştur';

  @override
  String profile_inv_applicants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count başvuran',
    );
    return '$_temp0';
  }

  @override
  String get profile_inv_expired => 'Süresi doldu';

  @override
  String profile_inv_hours_left(int h) {
    return '${h}sa kaldı';
  }

  @override
  String profile_inv_minutes_left(int m) {
    return '${m}dk';
  }

  @override
  String get sub_title => 'Abonelik';

  @override
  String get sub_status_active => 'Aktif';

  @override
  String get sub_status_cancelled => 'İptal edildi';

  @override
  String get sub_status_past_due => 'Ödeme sorunu';

  @override
  String get sub_none_title => 'Henüz abonelik yok';

  @override
  String get sub_none_body =>
      'Otomatik yenilenen Premium\'a geç veya 30 günlük tek seferlik erişim al.';

  @override
  String get sub_none_body_ios =>
      'Başka bir platformda başlatılan abonelik burada görünecek.';

  @override
  String get sub_get_premium => 'Premium\'a geç';

  @override
  String get sub_next_charge => 'Sonraki çekim';

  @override
  String get sub_card => 'Kart';

  @override
  String get sub_price_label => 'Tarife';

  @override
  String sub_premium_until(String date) {
    return 'Premium $date tarihine kadar aktif';
  }

  @override
  String get sub_cancel_button => 'Aboneliği iptal et';

  @override
  String get sub_cancel_confirm_title => 'Abonelik iptal edilsin mi?';

  @override
  String sub_cancel_confirm_body(String date) {
    return 'Otomatik yenileme kapatılacak. Premium $date tarihine kadar aktif kalacak.';
  }

  @override
  String get sub_cancel_confirm_yes => 'Aboneliği iptal et';

  @override
  String get sub_cancel_confirm_no => 'Vazgeç';

  @override
  String sub_cancelled_note(String date) {
    return 'Abonelik iptal edildi. Premium $date tarihine kadar aktif.';
  }

  @override
  String sub_resume_button(String last4) {
    return '•••• $last4 ile devam et';
  }

  @override
  String get sub_history_title => 'Ödemeler';

  @override
  String get sub_email_label => 'Çek ve bildirimler için e-posta';

  @override
  String get sub_consent =>
      'Oferta koşullarını kabul ediyor, abonelik iptal edilene kadar her 30 günde bir 1 000 ₽ otomatik çekilmesine onay veriyorum';

  @override
  String get sub_subscribe_cta => 'Abone ol — 1000 ₽/ay';

  @override
  String get sub_onetime_cta => 'Tek seferlik 30 gün — 1000 ₽';

  @override
  String get sub_auto_renews =>
      'Her 30 günde bir otomatik yenilenir. İstediğin zaman iptal.';

  @override
  String get sub_already_active => 'Zaten aktif bir aboneliğin var.';

  @override
  String get sub_use_resume_hint =>
      'Aboneliğin iptal edilmiş ama dönem hâlâ aktif — Profil → Abonelik\'ten devam ettirebilirsin.';

  @override
  String get sub_email_invalid => 'Geçerli bir e-posta gir.';

  @override
  String get sub_consent_required => 'Devam etmek için koşulları kabul et.';

  @override
  String get sub_continue => 'Devam';

  @override
  String get sub_retry_button => 'Ödemeyi tekrar dene';

  @override
  String get sub_retry_failed =>
      'Çekim başarısız. Kartını kontrol edip daha sonra tekrar dene.';

  @override
  String get sub_retry_limit =>
      'Bugün için deneme sınırına ulaşıldı — yarın tekrar dene.';

  @override
  String sub_resumed_note(String date) {
    return 'Otomatik yenileme açıldı. Sonraki çekim — $date.';
  }

  @override
  String sub_price_month(String price) {
    return '$price ₽ / ay';
  }

  @override
  String get profile_setup_email_label =>
      'E-posta (isteğe bağlı) — çek ve haberler için';

  @override
  String get profile_setup_email_hint => 'you@example.com';

  @override
  String get profile_setup_marketing_consent =>
      'SoulChoice haber ve özel tekliflerini (tanıtım dahil) e-posta ile almayı kabul ediyorum. Onayı istediğin zaman ayarlardan veya support@soulchoice.app adresine yazarak geri çekebilirsin.';

  @override
  String get paywall_subtitle_ios => 'Premium sınırsızı açar.';
}
