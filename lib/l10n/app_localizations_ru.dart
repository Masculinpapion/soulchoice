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
      'Ресторан, концерт, мероприятие. Открой приглашение, угости и сам выбери, с кем пойдёшь.';

  @override
  String get onboarding_2_title =>
      'Скажи, куда хочешь пойти — и тебя пригласят';

  @override
  String get onboarding_2_desc =>
      'Кафе, театр, концерт. Поделись желанием и жди того, кто угостит и сводит тебя.';

  @override
  String get onboarding_3_title =>
      'Проверенные профили, ответственное сообщество';

  @override
  String get onboarding_3_desc =>
      'Каждый профиль подтверждается через селфи. Те, кто не приходит на встречу или ведёт себя неподобающе, блокируются.';

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

  @override
  String get settings_title => 'Настройки';

  @override
  String get settings_profile_section => 'ПРОФИЛЬ';

  @override
  String get settings_edit_profile => 'Редактировать профиль';

  @override
  String get settings_edit_photos => 'Редактировать фото';

  @override
  String get settings_notification_prefs => 'Настройки уведомлений';

  @override
  String get settings_do_not_disturb => 'Не беспокоить';

  @override
  String get settings_active_devices => 'Активные устройства';

  @override
  String get settings_download_data => 'Загрузить мои данные';

  @override
  String get phone_title => 'Введи свой\nномер телефона';

  @override
  String get phone_subtitle => 'Мы отправим тебе код подтверждения';

  @override
  String get phone_error_empty => 'Введи номер телефона';

  @override
  String get phone_error_connection => 'Ошибка подключения, попробуй ещё раз';

  @override
  String get phone_terms => 'Продолжая, ты принимаешь';

  @override
  String get phone_terms_link_privacy => 'Политику конфиденциальности';

  @override
  String get phone_terms_link_terms => 'Условия использования';

  @override
  String get otp_title => 'Введи код';

  @override
  String get otp_sent_to => 'Звонок поступит на номер ';

  @override
  String get otp_call_hint => 'Введи последние 4 цифры входящего номера';

  @override
  String otp_resend_countdown(int seconds) {
    return 'Отправить снова ($secondsс)';
  }

  @override
  String get otp_resend => 'Отправить снова';

  @override
  String get otp_verify => 'Подтвердить';

  @override
  String get otp_error_failed => 'Подтверждение не удалось';

  @override
  String get perm_notification_title => 'Разрешить уведомления';

  @override
  String get perm_notification_desc =>
      'Нужно, чтобы уведомлять тебя о новых сообщениях при выборе';

  @override
  String get perm_location_title => 'Поделиться геолокацией';

  @override
  String get perm_location_desc =>
      'Нам нужна твоя геолокация, чтобы показывать ближайшие приглашения';

  @override
  String get perm_photos_title => 'Доступ к галерее фото';

  @override
  String get perm_photos_desc => 'Нужно для добавления фотографий в профиль';

  @override
  String get perm_grant => 'Разрешить';

  @override
  String get perm_not_now => 'Не сейчас';

  @override
  String get perm_denied_hint =>
      'Ты можешь разрешить это в настройках, чтобы использовать эту функцию';

  @override
  String get perm_go_to_settings => 'Перейти в настройки';

  @override
  String get perm_camera_title => 'Разрешить доступ к камере';

  @override
  String get perm_camera_desc =>
      'Нужно для фотографирования селфи при верификации';

  @override
  String get feed_all_cities => 'Все города';

  @override
  String get feed_active_invitations => 'АКТИВНЫЕ ПРИГЛАШЕНИЯ';

  @override
  String get feed_active_requests => 'АКТИВНЫЕ ЗАПРОСЫ';

  @override
  String get feed_24h_badge => '24 ЧАСА';

  @override
  String feed_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get feed_no_invitations => 'Пока нет приглашений';

  @override
  String get feed_be_first => 'Будь первым!';

  @override
  String get feed_todays_invitations => 'ПРИГЛАШЕНИЯ СЕГОДНЯ';

  @override
  String get feed_todays_requests => 'ЗАПРОСЫ СЕГОДНЯ';

  @override
  String get feed_swipe_hint => '· ЛИСТАЙ →';

  @override
  String get feed_cta_invite => 'Хочу прийти';

  @override
  String get feed_cta_request => 'Хочу присоединиться';

  @override
  String get feed_city_picker_title => 'Выбрать город';

  @override
  String get feed_city_search_hint => 'Поиск города…';

  @override
  String feed_city_not_found(String query) {
    return 'Город \"$query\" не найден';
  }

  @override
  String get feed_tab_invitations => 'Приглашения';

  @override
  String get feed_tab_requests => 'Запросы';

  @override
  String get feed_city_name_moscow => 'Москва';

  @override
  String get discover_title => 'Обзор';

  @override
  String get discover_all_invitations_label => 'ВСЕ АКТИВНЫЕ ПРИГЛАШЕНИЯ';

  @override
  String get discover_filter_all => 'Все';

  @override
  String get discover_empty_title => 'Пока нет активных приглашений';

  @override
  String get discover_empty_subtitle =>
      'Будь первым, кто откроет приглашение здесь';

  @override
  String get discover_btn_create => '+ Создать приглашение';

  @override
  String get discover_error => 'Ошибка подключения';

  @override
  String get applicants_title => 'Заявки';

  @override
  String applicants_count(int count) {
    return '$count человек';
  }

  @override
  String get applicants_empty => 'Пока нет заявок';

  @override
  String get applicants_select_btn => 'Выбрать';

  @override
  String get applicants_error_already_matched => 'Это приглашение уже совпало';

  @override
  String get applicants_error_not_authorized => 'Ошибка авторизации';

  @override
  String applicants_error_generic(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get create_inv_step_flow_type => 'Тип приглашения';

  @override
  String get create_inv_step_category => 'Категория';

  @override
  String get create_inv_step_title => 'Заголовок';

  @override
  String get create_inv_step_description => 'Описание';

  @override
  String get create_inv_step_venue => 'Место';

  @override
  String get create_inv_step_datetime => 'Дата и время';

  @override
  String get create_inv_step_duration => 'Длительность';

  @override
  String get create_inv_validation_category => 'Пожалуйста, выбери категорию';

  @override
  String get create_inv_validation_title => 'Заголовок не может быть пустым';

  @override
  String get create_inv_validation_venue =>
      'Название места не может быть пустым';

  @override
  String get create_inv_validation_date => 'Пожалуйста, выбери дату и время';

  @override
  String create_inv_error_publish(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get create_inv_btn_next => 'Далее';

  @override
  String get create_inv_btn_publish => 'Опубликовать';

  @override
  String get create_inv_btn_update => 'Обновить';

  @override
  String get create_inv_flow_invite_title => 'Приглашаю';

  @override
  String get create_inv_flow_invite_subtitle => '';

  @override
  String get create_inv_flow_request_title => 'Жду приглашения';

  @override
  String get create_inv_flow_request_subtitle => '';

  @override
  String get create_inv_flow_question => 'Что ты хочешь открыть?';

  @override
  String get create_inv_category_question => 'Каким опытом ты делишься?';

  @override
  String get create_inv_title_subtitle =>
      'Коротко и ёмко — будет крупно в ленте';

  @override
  String get create_inv_title_label => 'Заголовок';

  @override
  String get create_inv_desc_invite_hint => 'Куда идёшь?';

  @override
  String get create_inv_desc_request_hint => 'Куда хочешь пойти?';

  @override
  String get create_inv_desc_input_hint => 'Напиши подробности...';

  @override
  String get create_inv_venue_question => 'Где?';

  @override
  String get create_inv_venue_subtitle =>
      'Короткое название места — кафе, ресторан, парк';

  @override
  String get create_inv_venue_label => 'Название места';

  @override
  String get create_inv_venue_placeholder => 'Напр. Кафе Пушкинъ, Стрелка...';

  @override
  String get create_inv_duration_question => 'Срок действия';

  @override
  String get create_inv_duration_subtitle =>
      'По истечении этого времени приглашение исчезнет из ленты';

  @override
  String get create_inv_duration_6h => '6 часов';

  @override
  String get create_inv_duration_6h_desc => 'Краткосрочное — на сегодня';

  @override
  String get create_inv_duration_12h => '12 часов';

  @override
  String get create_inv_duration_12h_desc => 'Полдня';

  @override
  String get create_inv_duration_24h => '24 часа';

  @override
  String get create_inv_duration_24h_desc => 'Стандарт — 1 день';

  @override
  String get create_inv_duration_48h => '48 часов';

  @override
  String get create_inv_duration_48h_desc => 'Долгосрочное — 2 дня';

  @override
  String get create_inv_datetime_question => 'Когда?';

  @override
  String get create_inv_datetime_subtitle => 'Выбери дату и время мероприятия';

  @override
  String get create_inv_venue_ph_food => 'Название ресторана';

  @override
  String get create_inv_venue_ph_bar => 'Название бара';

  @override
  String get create_inv_venue_ph_coffee => 'Название кафе';

  @override
  String get create_inv_venue_ph_sport => 'Название корта или клуба';

  @override
  String get create_inv_venue_ph_walk => 'Парк или место встречи';

  @override
  String get create_inv_venue_ph_karaoke => 'Название караоке-бара';

  @override
  String get create_inv_venue_ph_cinema => 'Название кинотеатра';

  @override
  String get create_inv_venue_ph_theater => 'Название театра';

  @override
  String get create_inv_venue_ph_concert => 'Название площадки';

  @override
  String get create_inv_venue_ph_culture => 'Название места';

  @override
  String get create_inv_venue_ph_travel => 'Город или страна';

  @override
  String get create_inv_venue_ph_gift => 'Где встретимся?';

  @override
  String get create_inv_validation_description_travel =>
      'Напишите, куда хотите поехать';

  @override
  String get create_inv_venue_question_gift => 'Где встретимся?';

  @override
  String get create_inv_venue_subtitle_gift =>
      'Место встречи, где вы передадите подарок';

  @override
  String get create_inv_venue_subtitle_gift_request =>
      'Место встречи, где вы получите подарок';

  @override
  String get create_inv_venue_question_cinema => 'В каком кинотеатре?';

  @override
  String get create_inv_venue_subtitle_cinema =>
      'Кинотеатр, где вы посмотрите фильм';

  @override
  String get create_inv_venue_question_theater => 'В каком театре?';

  @override
  String get create_inv_venue_subtitle_theater =>
      'Театр, где пройдёт спектакль';

  @override
  String get create_inv_venue_question_concert => 'На какой площадке?';

  @override
  String get create_inv_venue_subtitle_concert =>
      'Площадка, где пройдёт мероприятие';

  @override
  String get create_inv_desc_invite_food => 'Куда идёшь?';

  @override
  String get create_inv_desc_invite_bar => 'Куда идёшь?';

  @override
  String get create_inv_desc_invite_coffee => 'Куда идёшь?';

  @override
  String get create_inv_desc_invite_cinema => 'Название фильма?';

  @override
  String get create_inv_desc_invite_theater => 'Название спектакля?';

  @override
  String get create_inv_desc_invite_concert => 'Название мероприятия?';

  @override
  String get create_inv_desc_invite_culture => 'Куда идёшь?';

  @override
  String get create_inv_desc_invite_travel => 'Куда едете?';

  @override
  String get create_inv_desc_invite_gift => 'Что хочешь подарить?';

  @override
  String get create_inv_desc_request_food => 'Куда хочешь пойти?';

  @override
  String get create_inv_desc_request_bar => 'Куда хочешь пойти?';

  @override
  String get create_inv_desc_request_coffee => 'Куда хочешь пойти?';

  @override
  String get create_inv_desc_request_cinema => 'Какой фильм хочешь посмотреть?';

  @override
  String get create_inv_desc_request_theater =>
      'Какой спектакль хочешь увидеть?';

  @override
  String get create_inv_desc_request_concert =>
      'На какое мероприятие хочешь попасть?';

  @override
  String get create_inv_desc_request_culture => 'Куда хочешь пойти?';

  @override
  String get create_inv_desc_request_travel => 'Куда хочешь поехать?';

  @override
  String get create_inv_desc_invite_sport => 'Какая активность?';

  @override
  String get create_inv_desc_request_sport => 'Чем хочешь заняться?';

  @override
  String get create_inv_desc_invite_walk => 'Где гуляешь?';

  @override
  String get create_inv_desc_request_walk => 'Где хочешь погулять?';

  @override
  String get create_inv_desc_invite_karaoke => 'Где поёшь?';

  @override
  String get create_inv_desc_request_karaoke => 'Где хочешь спеть?';

  @override
  String get create_inv_desc_request_gift => 'Что хочешь получить в подарок?';

  @override
  String get create_inv_datetime_placeholder => 'Выбрать дату и время';

  @override
  String get decision_selected_title => 'Подтверждение выбора';

  @override
  String decision_selected_body(String name, String title) {
    return 'Вы выбрали $name для вашего приглашения \"$title\".\nХотите подтвердить это совпадение?';
  }

  @override
  String get decision_time_remaining => 'осталось времени';

  @override
  String get decision_time_expired => 'Время истекло';

  @override
  String get decision_accept => 'Да, подтверждаю';

  @override
  String get decision_reject => 'Нет, отменить';

  @override
  String get decision_fallback_name => 'Пользователь';

  @override
  String decision_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get inv_detail_not_found => 'Приглашение не найдено';

  @override
  String get inv_detail_delete_title => 'Удалить приглашение';

  @override
  String inv_detail_delete_body(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female':
          'Ты уверена, что хочешь удалить это приглашение? Это действие необратимо.',
      'other':
          'Ты уверен, что хочешь удалить это приглашение? Это действие необратимо.',
    });
    return '$_temp0';
  }

  @override
  String get inv_detail_delete_cancel => 'Отмена';

  @override
  String get inv_detail_delete_confirm => 'Удалить';

  @override
  String get inv_detail_status_closed => 'Это приглашение закрыто';

  @override
  String get inv_detail_status_meeting => 'Встреча';

  @override
  String get inv_detail_status_decision => 'ВРЕМЯ РЕШЕНИЯ';

  @override
  String get inv_detail_status_selecting => 'ОКНО ВЫБОРА';

  @override
  String get inv_detail_status_awaiting => 'ОЖИДАНИЕ ВЫБОРА';

  @override
  String get inv_detail_status_remaining => 'ОСТАЛОСЬ ВРЕМЕНИ';

  @override
  String get inv_detail_status_expired => 'Истекло';

  @override
  String get inv_detail_day_mon => 'Пн';

  @override
  String get inv_detail_day_tue => 'Вт';

  @override
  String get inv_detail_day_wed => 'Ср';

  @override
  String get inv_detail_day_thu => 'Чт';

  @override
  String get inv_detail_day_fri => 'Пт';

  @override
  String get inv_detail_day_sat => 'Сб';

  @override
  String get inv_detail_day_sun => 'Вс';

  @override
  String get inv_detail_directions => 'Маршрут';

  @override
  String get inv_detail_section_invitation => 'ПРИГЛАШЕНИЕ';

  @override
  String get inv_detail_section_details => 'ДЕТАЛИ';

  @override
  String get inv_detail_section_host => 'ОРГАНИЗАТОР';

  @override
  String get inv_detail_host_label => 'Организатор приглашения';

  @override
  String get inv_detail_section_with_whom => 'С КЕМ';

  @override
  String get inv_detail_section_who => 'КТО';

  @override
  String get inv_detail_applicants_btn => 'Посмотреть заявки';

  @override
  String get inv_detail_loading => 'Загрузка...';

  @override
  String get inv_detail_error_label => 'Ошибка';

  @override
  String get inv_detail_apply_invite => 'Хочу прийти';

  @override
  String get inv_detail_apply_request => 'Хочу присоединиться';

  @override
  String get inv_detail_apply_sending => 'Отправка...';

  @override
  String get inv_detail_withdraw_title => 'Отозвать заявку';

  @override
  String inv_detail_withdraw_body(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'Ты уверена, что хочешь отозвать заявку на это приглашение?',
      'other': 'Ты уверен, что хочешь отозвать заявку на это приглашение?',
    });
    return '$_temp0';
  }

  @override
  String get inv_detail_withdraw_cancel => 'Отмена';

  @override
  String get inv_detail_withdraw_confirm => 'Отозвать';

  @override
  String get inv_detail_withdraw_btn => 'Отозвать заявку';

  @override
  String get inv_detail_withdrawing => 'Отмена...';

  @override
  String get inv_detail_selected_btn => 'Выбрали — Прими решение';

  @override
  String get inv_detail_accepted_btn => '✓ Принято';

  @override
  String get inv_detail_apply_sent_title => 'Заявка отправлена';

  @override
  String get inv_detail_apply_sent_body =>
      'Жди, пока владелец приглашения сделает выбор';

  @override
  String inv_detail_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get inv_detail_retry => 'Повторить';

  @override
  String inv_detail_duration_days_hours(int days, int hours) {
    return '$daysд $hoursч';
  }

  @override
  String inv_detail_duration_hours_min(int hours, int min) {
    return '$hoursч $minмин';
  }

  @override
  String inv_detail_duration_min(int min) {
    return '$minмин';
  }

  @override
  String get inv_detail_weekday_mon_full => 'Понедельник';

  @override
  String get inv_detail_weekday_tue_full => 'Вторник';

  @override
  String get inv_detail_weekday_wed_full => 'Среда';

  @override
  String get inv_detail_weekday_thu_full => 'Четверг';

  @override
  String get inv_detail_weekday_fri_full => 'Пятница';

  @override
  String get inv_detail_weekday_sat_full => 'Суббота';

  @override
  String get inv_detail_weekday_sun_full => 'Воскресенье';

  @override
  String get chat_archived => 'Этот чат в архиве';

  @override
  String get chat_meeting_question => 'Встреча состоялась?';

  @override
  String get chat_yes_we_met => 'Да, встретились';

  @override
  String get chat_other_no_show => 'Другая сторона не пришла';

  @override
  String chat_send_error(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get chat_meeting_saved => 'Спасибо! Встреча записана.';

  @override
  String get chat_noted => 'Принято.';

  @override
  String chat_other_age(int age) {
    return '$age лет';
  }

  @override
  String get chat_empty_hint => 'Отправь первое сообщение!';

  @override
  String get chat_input_hint => 'Написать сообщение...';

  @override
  String get messages_title => 'Сообщения';

  @override
  String get messages_tab_active => 'Активные';

  @override
  String get messages_tab_past => 'Прошлые';

  @override
  String get messages_connection_error => 'Ошибка подключения';

  @override
  String get messages_no_preview => 'Пока нет сообщений';

  @override
  String get messages_empty_past => 'Прошлых чатов нет';

  @override
  String get messages_empty_active => 'Пока нет активных чатов';

  @override
  String get messages_empty_hint =>
      'Открой приглашение или откликнись на существующее';

  @override
  String get messages_btn_create => 'Создать приглашение';

  @override
  String get notifications_title => 'Уведомления';

  @override
  String get notifications_mark_all_read => 'Прочитать все';

  @override
  String notifications_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get notifications_empty => 'Пока нет уведомлений';

  @override
  String get photo_upload_title_edit => 'Редактировать фото';

  @override
  String get photo_upload_title_add => 'Добавить фото';

  @override
  String photo_upload_subtitle(int min, int max, int filled, int total) {
    return 'Мин $min макс $max фото • $filled / $total';
  }

  @override
  String get photo_upload_primary_label => 'Главное фото';

  @override
  String get photo_upload_primary_badge => 'Главное';

  @override
  String get photo_upload_permission_error =>
      'Необходим доступ к галерее. Пожалуйста, разреши в настройках.';

  @override
  String photo_upload_pick_error(String error) {
    return 'Не удалось выбрать фото: $error';
  }

  @override
  String photo_upload_error(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get photo_upload_btn_save => 'Сохранить';

  @override
  String get photo_upload_btn_continue => 'Продолжить';

  @override
  String get photo_crop_title => 'Редактировать фото';

  @override
  String get photo_crop_apply => 'Применить';

  @override
  String photo_crop_error(String error) {
    return 'Ошибка обрезки: $error';
  }

  @override
  String get profile_setup_step_name_age => 'Имя и возраст';

  @override
  String get profile_setup_step_gender => 'Пол';

  @override
  String get profile_setup_step_city => 'Город';

  @override
  String get profile_setup_step_bio => 'О себе';

  @override
  String get profile_setup_step_job_edu => 'Работа / Образование';

  @override
  String get profile_setup_step_interests => 'Интересы';

  @override
  String get profile_setup_step_prompts => 'Вопросы';

  @override
  String get profile_setup_step_age_range => 'Возрастной диапазон';

  @override
  String get profile_setup_step_consent => 'Согласия';

  @override
  String get profile_setup_consent_subtitle =>
      'Прежде чем продолжить, подтвердите три пункта ниже.';

  @override
  String get profile_setup_consent_age => 'Мне исполнилось 18 лет';

  @override
  String get profile_setup_consent_data =>
      'Я даю согласие на обработку моих персональных данных в соответствии с';

  @override
  String get profile_setup_consent_data_link => 'Политикой конфиденциальности';

  @override
  String get profile_setup_consent_visibility =>
      'Я разрешаю показывать мой профиль (фото, имя, возраст, город) другим пользователям сервиса';

  @override
  String get profile_setup_validation_gender => 'Пожалуйста, выберите пол';

  @override
  String get profile_setup_validation_city => 'Пожалуйста, выберите город';

  @override
  String get profile_setup_validation_name => 'Имя не может быть пустым';

  @override
  String profile_setup_validation_age(int min, int max) {
    return 'Возраст должен быть от $min до $max';
  }

  @override
  String profile_setup_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get profile_setup_btn_next => 'Далее';

  @override
  String get profile_setup_btn_add_photos => 'Добавить фото';

  @override
  String get profile_setup_name_question => 'Как тебя зовут?';

  @override
  String get profile_setup_name_label => 'Имя';

  @override
  String profile_setup_age_label(int min, int max) {
    return 'Возраст ($min-$max)';
  }

  @override
  String get profile_setup_gender_title => 'Пол';

  @override
  String get profile_setup_gender_female => 'Женский';

  @override
  String get profile_setup_gender_male => 'Мужской';

  @override
  String get profile_setup_city_question => 'В каком ты городе?';

  @override
  String get profile_setup_city_search => 'Поиск города...';

  @override
  String get profile_setup_city_not_found => 'Город не найден';

  @override
  String get profile_setup_bio_title => 'Расскажи о себе';

  @override
  String get profile_setup_bio_subtitle =>
      'Необязательно — максимум 200 символов';

  @override
  String get profile_setup_bio_hint => 'Коротко представься...';

  @override
  String get profile_setup_job_title => 'Работа и образование';

  @override
  String get profile_setup_job_subtitle => 'Необязательно';

  @override
  String get profile_setup_job_label => 'Профессия';

  @override
  String get profile_setup_education_label => 'Школа / Университет';

  @override
  String get profile_setup_interests_title => 'Интересы';

  @override
  String get profile_setup_interests_subtitle => 'Выбери не менее 3';

  @override
  String get profile_setup_prompts_title => 'Несколько вопросов';

  @override
  String get profile_setup_prompts_subtitle =>
      'Необязательно — обогащает твой профиль';

  @override
  String get profile_setup_prompts_answer_hint => 'Твой ответ...';

  @override
  String get profile_setup_age_range_title =>
      'Какой возрастной диапазон тебя интересует?';

  @override
  String get profile_setup_age_range_subtitle =>
      'В ленте будут показываться только приглашения в этом возрастном диапазоне';

  @override
  String profile_setup_age_range_value(int min, int max) {
    return '$min — $max лет';
  }

  @override
  String get profile_setup_prompt_favorite_restaurant =>
      'МОЙ ЛЮБИМЫЙ РЕСТОРАН...';

  @override
  String profile_setup_prompt_last_book(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'ПОСЛЕДНЯЯ КНИГА, КОТОРУЮ Я ЧИТАЛА...',
      'other': 'ПОСЛЕДНЯЯ КНИГА, КОТОРУЮ Я ЧИТАЛ...',
    });
    return '$_temp0';
  }

  @override
  String get profile_setup_prompt_perfect_evening => 'ИДЕАЛЬНЫЙ ВЕЧЕР...';

  @override
  String get profile_setup_prompt_travel_dream => 'МОЯ МЕЧТА О ПУТЕШЕСТВИИ...';

  @override
  String get profile_setup_interest_art => 'Искусство';

  @override
  String get profile_setup_interest_music => 'Музыка';

  @override
  String get profile_setup_interest_sports => 'Спорт';

  @override
  String get profile_setup_interest_books => 'Книги';

  @override
  String get profile_setup_interest_travel => 'Путешествия';

  @override
  String get profile_setup_interest_food => 'Еда';

  @override
  String get profile_setup_interest_film => 'Кино';

  @override
  String get profile_setup_interest_theatre => 'Театр';

  @override
  String get profile_setup_interest_dance => 'Танцы';

  @override
  String get profile_setup_interest_yoga => 'Йога';

  @override
  String get profile_setup_interest_photography => 'Фотография';

  @override
  String get profile_setup_interest_games => 'Игры';

  @override
  String get profile_setup_interest_technology => 'Технологии';

  @override
  String get profile_setup_interest_nature => 'Природа';

  @override
  String get profile_setup_interest_history => 'История';

  @override
  String get profile_setup_interest_fashion => 'Мода';

  @override
  String get profile_view_not_found => 'Профиль не найден';

  @override
  String get profile_view_hint_name_age => 'Имя и возраст не указаны';

  @override
  String get profile_view_hint_photo => 'Добавь фото';

  @override
  String get profile_view_hint_bio => 'Добавь описание';

  @override
  String get profile_view_hint_interests => 'Добавь интересы';

  @override
  String get profile_view_hint_selfie_pending => 'Селфи на проверке...';

  @override
  String get profile_view_hint_selfie_upload => 'Загрузить селфи';

  @override
  String get profile_view_hint_prompt => 'Ответить на вопрос';

  @override
  String profile_view_completion(int score) {
    return '$score% заполнено';
  }

  @override
  String get profile_view_section_interests => 'ИНТЕРЕСЫ';

  @override
  String get profile_view_section_prompts => 'ВЫРАЖЕНИЯ';

  @override
  String get profile_view_cta_edit => 'Редактировать профиль';

  @override
  String get profile_view_cta_come => 'Хочу прийти';

  @override
  String get profile_view_action_block => 'Заблокировать пользователя';

  @override
  String get profile_view_action_block_confirm => 'Заблокировать';

  @override
  String get profile_view_action_block_cancel => 'Отмена';

  @override
  String get profile_view_action_report => 'Пожаловаться';

  @override
  String get profile_view_action_cancel => 'Отмена';

  @override
  String profile_view_blocked_snack(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name заблокирована',
      'other': '$name заблокирован',
    });
    return '$_temp0';
  }

  @override
  String get profile_view_block_confirm_body =>
      'Вы уверены, что хотите заблокировать этого пользователя?';

  @override
  String get profile_view_anonymous_user => 'Пользователь';

  @override
  String get report_title => 'Пожаловаться на пользователя';

  @override
  String get report_why => 'Почему ты жалуешься?';

  @override
  String get report_reason_inappropriate => 'Неприемлемый контент / фото';

  @override
  String get report_reason_harassment => 'Домогательства или угрозы';

  @override
  String get report_reason_spam => 'Спам или фейковый аккаунт';

  @override
  String get report_reason_illegal => 'Незаконная деятельность';

  @override
  String get report_reason_other => 'Другое';

  @override
  String get report_desc_label => 'Описание (необязательно)';

  @override
  String get report_desc_label_required => 'Описание (обязательно)';

  @override
  String get report_desc_hint => 'Можешь добавить подробности...';

  @override
  String get report_btn_sending => 'Отправка...';

  @override
  String get report_btn_submit => 'Отправить жалобу';

  @override
  String get report_error_no_reason => 'Пожалуйста, выбери причину';

  @override
  String get report_error_desc_required =>
      'Для причины \"Другое\" нужно написать описание';

  @override
  String get report_success => 'Твоя жалоба получена, мы её рассмотрим';

  @override
  String report_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get selfie_title => 'Верификация через селфи';

  @override
  String get selfie_subtitle =>
      'Мы вручную проверяем твой профиль для безопасного сообщества';

  @override
  String get selfie_take_btn => 'Сделать селфи';

  @override
  String get selfie_tip_lighting => 'Снимай в хорошо освещённом месте';

  @override
  String get selfie_tip_face => 'Твоё лицо должно быть чётко видно';

  @override
  String get selfie_tip_approval =>
      'Администратор проверяет в течение 24 часов';

  @override
  String get selfie_submit_btn => 'Отправить';

  @override
  String get blocked_users_title => 'Чёрный список';

  @override
  String get blocked_users_empty => 'Нет заблокированных пользователей';

  @override
  String get blocked_users_unblock_btn => 'Разблокировать';

  @override
  String get delete_account_title => 'Удалить аккаунт';

  @override
  String get delete_account_heading => 'Это действие необратимо';

  @override
  String get delete_account_body =>
      'Если ты удалишь аккаунт, все твои данные, сообщения, совпадения и фото будут безвозвратно удалены. Это нельзя отменить.';

  @override
  String get delete_account_warn_profile =>
      'Твой профиль и все фото будут удалены';

  @override
  String get delete_account_warn_messages =>
      'Вся история сообщений будет удалена';

  @override
  String get delete_account_warn_invitations =>
      'Твои активные приглашения и заявки будут удалены';

  @override
  String get delete_account_warn_phone =>
      'Ты не сможешь снова зарегистрироваться с тем же номером телефона';

  @override
  String get delete_account_checkbox =>
      'Да, я хочу безвозвратно удалить свой аккаунт';

  @override
  String get delete_account_btn_delete => 'Удалить аккаунт навсегда';

  @override
  String get delete_account_btn_cancel => 'Отмена';

  @override
  String get delete_account_success =>
      'Твой аккаунт помечен для удаления. Вскоре он будет удалён окончательно.';

  @override
  String get delete_account_error =>
      'Произошла ошибка. Пожалуйста, попробуй ещё раз.';

  @override
  String get settings_coming_soon => 'Эта функция скоро появится.';

  @override
  String get settings_ok => 'ОК';

  @override
  String get settings_about_subtitle =>
      'Премиум-приложение для социальных приглашений.';

  @override
  String get settings_share_subject => 'Экспорт данных SoulChoice';

  @override
  String settings_error(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get settings_quiet_hours_title => 'Ночная тишина';

  @override
  String get settings_quiet_active => 'Активно';

  @override
  String get settings_quiet_start => 'Начало';

  @override
  String get settings_quiet_end => 'Конец';

  @override
  String get settings_age_range_title => 'Возрастной диапазон';

  @override
  String settings_age_range_value(int min, int max) {
    return '$min — $max лет';
  }

  @override
  String get settings_privacy_section => 'КОНФИДЕНЦИАЛЬНОСТЬ И БЕЗОПАСНОСТЬ';

  @override
  String get settings_blocked_users => 'Чёрный список';

  @override
  String get settings_location_permission => 'Разрешение геолокации';

  @override
  String get settings_camera_permission => 'Разрешение камеры';

  @override
  String get settings_support_section => 'ПОДДЕРЖКА';

  @override
  String get settings_help => 'Помощь и поддержка';

  @override
  String get settings_about => 'О приложении';

  @override
  String get settings_logout_error =>
      'Не удалось выйти. Пожалуйста, попробуй ещё раз.';

  @override
  String get settings_selfie_pending => 'Селфи на проверке';

  @override
  String get settings_selfie_approved => 'Аккаунт верифицирован';

  @override
  String get settings_selfie_rejected => 'Селфи отклонено — загрузи снова';

  @override
  String get settings_selfie_none => 'Селфи ещё не загружено';

  @override
  String get settings_verification_status => 'Статус верификации';

  @override
  String get settings_reupload => 'Загрузить снова';

  @override
  String get admin_title => 'Модерация';

  @override
  String get admin_tab_selfies => 'Проверка селфи';

  @override
  String get admin_tab_reports => 'Жалобы';

  @override
  String get admin_reject_reason_title => 'Причина отклонения';

  @override
  String get admin_reject_reason_no_face => 'Лицо не видно';

  @override
  String get admin_reject_reason_inappropriate => 'Неприемлемый контент';

  @override
  String get admin_reject_reason_mismatch =>
      'Другой человек (не совпадает с фото профиля)';

  @override
  String get admin_reject_reason_quality => 'Низкое качество / размыто';

  @override
  String get admin_reject_reason_other => 'Другое';

  @override
  String get admin_btn_cancel => 'Отмена';

  @override
  String get admin_btn_reject => 'Отклонить';

  @override
  String get admin_selfies_empty => 'Нет ожидающих селфи';

  @override
  String get admin_view_profile => 'Просмотреть профиль';

  @override
  String get admin_photo_label_profile => 'Фото профиля';

  @override
  String get admin_photo_label_selfie => 'Селфи';

  @override
  String get admin_btn_approve => '✅ Одобрить';

  @override
  String get admin_btn_reject_action => '❌ Отклонить';

  @override
  String get admin_reports_empty => 'Нет ожидающих жалоб';

  @override
  String admin_report_about(String name) {
    return 'жалоба на $name';
  }

  @override
  String admin_reporter_label(String name) {
    return 'Жалующийся: $name';
  }

  @override
  String admin_reason_label(String reason) {
    return 'Причина: $reason';
  }

  @override
  String get admin_user_banned => 'Пользователь заблокирован';

  @override
  String get admin_btn_ban => 'Заблокировать';

  @override
  String get admin_btn_dismiss => 'Отклонить';

  @override
  String get category_food => 'Ресторан';

  @override
  String get category_concert => 'Концерт';

  @override
  String get category_travel => 'Путешествие';

  @override
  String get category_culture => 'Культура';

  @override
  String get category_cinema => 'Кино';

  @override
  String get category_theater => 'Театр';

  @override
  String get category_coffee => 'Кофе';

  @override
  String get category_bar => 'Бар';

  @override
  String get category_gift => 'Подарок';

  @override
  String get category_sport => 'Спорт';

  @override
  String get category_walk => 'Прогулка';

  @override
  String get category_karaoke => 'Караоке';

  @override
  String get notif_type_new_application_title => 'Новая заявка';

  @override
  String notif_type_new_application_body(String name) {
    return 'Поступила заявка от $name';
  }

  @override
  String get notif_type_selected_title => 'Тебя выбрали! 🎉';

  @override
  String get notif_type_selected_body => 'Ты отправляешься на встречу';

  @override
  String get notif_type_not_selected_title => 'В этот раз не вышло';

  @override
  String get notif_type_not_selected_body => 'Не расстраивайся, продолжай';

  @override
  String get notif_type_new_message_title => 'Новое сообщение';

  @override
  String notif_type_new_message_body(String name) {
    return 'Сообщение от $name';
  }

  @override
  String get notif_type_selfie_approved_title => 'Профиль подтверждён ✓';

  @override
  String get notif_type_selfie_approved_body =>
      'Теперь ты можешь участвовать в приглашениях';

  @override
  String get notif_type_selfie_rejected_title => 'Фото отклонено';

  @override
  String get notif_type_selfie_rejected_body =>
      'Пожалуйста, загрузи новое селфи';

  @override
  String get notif_type_meeting_reminder_title => 'Напоминание о встрече';

  @override
  String get notif_type_meeting_reminder_body => 'Скоро начнётся твоя встреча';

  @override
  String get notif_type_feedback_request_title => 'Как прошла встреча?';

  @override
  String get notif_type_feedback_request_body => 'Расскажи о своём опыте';

  @override
  String get notif_action_new_message => 'отправил(а) сообщение';

  @override
  String get notif_type_new_application_body_noname => 'Поступила новая заявка';

  @override
  String get notif_type_new_message_body_noname => 'Новое сообщение';

  @override
  String notif_grouped_messages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых сообщения',
      many: '$count новых сообщений',
      few: '$count новых сообщения',
      one: '$count новое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get notif_action_new_application =>
      'откликнулся(ась) на ваше приглашение';

  @override
  String get notif_action_selected => 'выбрал(а) тебя 🎉';

  @override
  String get notif_action_not_selected => 'ответил(а) на твою заявку';

  @override
  String get chat_delete_conversation => 'Удалить чат';

  @override
  String get chat_block_and_close => 'Заблокировать и закрыть';

  @override
  String get chat_block => 'Заблокировать';

  @override
  String get chat_open => 'Чат открыт';

  @override
  String get chat_delete_confirm_body =>
      'Хочешь удалить этот чат? Он переместится в архив.';

  @override
  String chat_block_confirm_body(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female':
          'Ты уверена, что хочешь заблокировать этого человека? Чат закроется.',
      'other':
          'Ты уверен, что хочешь заблокировать этого человека? Чат закроется.',
    });
    return '$_temp0';
  }

  @override
  String get error_page_not_found => 'Страница не найдена';

  @override
  String error_with_detail(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get create_inv_gate_title => 'Сначала одобрение селфи';

  @override
  String get create_inv_gate_none =>
      'Для безопасности нужно загрузить селфи перед созданием приглашения.';

  @override
  String get create_inv_gate_pending =>
      'Твоё селфи проверяется. Админ одобрит в течение 24 часов — после одобрения сможешь создавать приглашения.';

  @override
  String get create_inv_gate_rejected =>
      'Твоё селфи отклонено. Пожалуйста, загрузи новое.';

  @override
  String get create_inv_gate_action_upload => 'Сделать селфи';

  @override
  String get create_inv_gate_action_ok => 'Понятно';

  @override
  String get create_inv_active_limit_title_invite =>
      'У тебя уже есть активное приглашение';

  @override
  String get create_inv_active_limit_title_request =>
      'У тебя уже есть активный запрос';

  @override
  String get create_inv_active_limit_body =>
      'Прежде чем создать новое, нужно дождаться истечения срока текущего или отменить его.';

  @override
  String get create_inv_active_limit_cta_view => 'Посмотреть текущее';

  @override
  String get create_inv_active_limit_cta_ok => 'Понятно';

  @override
  String get create_inv_error_active_limit =>
      'У тебя уже есть активное приглашение или запрос, создать новое нельзя.';

  @override
  String get paywall_title => 'Бесплатная заявка использована';

  @override
  String get paywall_subtitle => 'Для безлимитных заявок оформи подписку.';

  @override
  String get paywall_perk_unlimited_invitations => 'Безлимитные приглашения';

  @override
  String get paywall_perk_unlimited_applications => 'Безлимитные заявки';

  @override
  String get paywall_perk_chat_after_match => 'Чат после взаимного выбора';

  @override
  String get paywall_perk_priority_moderation => 'Приоритет модерации';

  @override
  String get paywall_price => '1000₽ / месяц';

  @override
  String get paywall_cta => 'Продолжить';

  @override
  String get paywall_cancel_anytime => 'Отменить можно в любой момент.';

  @override
  String get paywall_coming_soon =>
      'Платёжная система скоро — ждём регистрацию ИП.';

  @override
  String get paywall_close => 'Закрыть';

  @override
  String get profile_inv_section => 'МОЯ ЗАЯВКА';

  @override
  String get profile_inv_empty_title => 'Активной заявки нет';

  @override
  String get profile_inv_create_cta => '+ Создать заявку';

  @override
  String profile_inv_applicants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заявки',
      many: '$count заявок',
      few: '$count заявки',
      one: '$count заявка',
    );
    return '$_temp0';
  }

  @override
  String get profile_inv_expired => 'Истекло';

  @override
  String profile_inv_hours_left(int h) {
    return '$hч осталось';
  }

  @override
  String profile_inv_minutes_left(int m) {
    return '$mмин';
  }

  @override
  String get sub_title => 'Подписка';

  @override
  String get sub_status_active => 'Активна';

  @override
  String get sub_status_cancelled => 'Отменена';

  @override
  String get sub_status_past_due => 'Проблема с оплатой';

  @override
  String get sub_none_title => 'Подписки пока нет';

  @override
  String get sub_none_body =>
      'Оформите Premium с автопродлением или разовый доступ на 30 дней.';

  @override
  String get sub_none_body_ios =>
      'Подписка, оформленная на другой платформе, появится здесь.';

  @override
  String get sub_get_premium => 'Оформить Premium';

  @override
  String get sub_next_charge => 'Следующее списание';

  @override
  String get sub_card => 'Карта';

  @override
  String get sub_price_label => 'Тариф';

  @override
  String sub_premium_until(String date) {
    return 'Premium активен до $date';
  }

  @override
  String get sub_cancel_button => 'Отменить подписку';

  @override
  String get sub_cancel_confirm_title => 'Отменить подписку?';

  @override
  String sub_cancel_confirm_body(String date) {
    return 'Автопродление будет отключено. Premium останется активным до $date.';
  }

  @override
  String get sub_cancel_confirm_yes => 'Отменить подписку';

  @override
  String get sub_cancel_confirm_no => 'Оставить';

  @override
  String sub_cancelled_note(String date) {
    return 'Подписка отменена. Premium активен до $date.';
  }

  @override
  String sub_resume_button(String last4) {
    return 'Продолжить с картой •••• $last4';
  }

  @override
  String get sub_history_title => 'Платежи';

  @override
  String get sub_email_label => 'E-mail для чеков и уведомлений';

  @override
  String get sub_consent =>
      'Соглашаюсь с условиями Оферты и даю согласие на автоматическое списание 1 000 ₽ каждые 30 дней до отмены подписки';

  @override
  String get sub_subscribe_cta => 'Оформить подписку — 1000 ₽/мес';

  @override
  String get sub_onetime_cta => 'Разовый доступ на 30 дней — 1000 ₽';

  @override
  String get sub_auto_renews =>
      'Продлевается автоматически каждые 30 дней. Отмена в любой момент.';

  @override
  String get sub_already_active => 'У вас уже есть активная подписка.';

  @override
  String get sub_use_resume_hint =>
      'Подписка отменена, но период ещё активен — возобновите её в Профиль → Подписка.';

  @override
  String get sub_email_invalid => 'Введите корректный e-mail.';

  @override
  String get sub_consent_required => 'Чтобы продолжить, примите условия.';

  @override
  String get sub_continue => 'Продолжить';

  @override
  String get sub_retry_button => 'Повторить оплату';

  @override
  String get sub_retry_failed =>
      'Списание не удалось. Проверьте карту и попробуйте позже.';

  @override
  String get sub_retry_limit =>
      'Слишком много попыток за сегодня — попробуйте завтра.';

  @override
  String sub_resumed_note(String date) {
    return 'Автопродление включено. Следующее списание — $date.';
  }

  @override
  String sub_price_month(String price) {
    return '$price ₽ / месяц';
  }

  @override
  String get profile_setup_email_label =>
      'E-mail (необязательно) — для чеков и новостей';

  @override
  String get profile_setup_email_hint => 'you@example.com';

  @override
  String get profile_setup_marketing_consent =>
      'Согласен(на) получать новости и специальные предложения SoulChoice, в том числе рекламные, по e-mail. Отозвать согласие можно в любой момент — в настройках или письмом на support@soulchoice.app.';

  @override
  String get paywall_subtitle_ios => 'Premium открывает безлимит.';
}
