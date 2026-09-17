import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform sorgularının web-güvenli hâli.
///
/// `dart:io`'nun `Platform` sınıfı web'de derlenir ama ÇAĞRILDIĞINDA fırlatır —
/// tarayıcı demosu (üniversite test kanalı, 01.08) beyaz ekranda kalıyordu.
/// Web'de iOS DEĞİL sayılır: ödeme/paywall akışı zaten web'de "link" modudur.
bool get isIOSDevice => !kIsWeb && Platform.isIOS;

/// RuStore Push vb. Android'e özgü yollar için web-güvenli kontrol (28.08).
bool get isAndroidDevice => !kIsWeb && Platform.isAndroid;

/// Sunucuya yazılan kaynak etiketi (`users.last_platform`, ödeme `source`).
String get platformTag => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

/// iOS «açık akış» paketi (17.09.2026, 6. Apple 4.3(b) reddi sonrası):
/// iOS'ta akış / Обзор / yüz şeridi cinsiyet ve yaş aralığına göre SÜZÜLMEZ
/// (herkes herkesi görür), sihirbazda yaş aralığı adımı ve ayarlarda yaş
/// aralığı satırı yok, «совпадение/match» yerine «выбор/choice» metni.
/// Derleme sabiti — uzaktan bayrak DEĞİL (2.3.1 bait-and-switch riski).
/// Android/RuStore/Play davranışı değişmez. Mekanik aynı: plan → başvuru →
/// tek kişiyi seç → sohbet.
bool get openFeedMode => isIOSDevice || _openFeedPreview;

/// YALNIZ yerel önizleme: `flutter run --dart-define=OPEN_FEED=true` ile
/// Android emülatörde iOS akışı görülür. Mağaza derlemelerinde tanımsız.
const bool _openFeedPreview = bool.fromEnvironment('OPEN_FEED');

/// Mağaza demo şehirleri DB'de «Moscow, Russia» / «Saint Petersburg, Russia»
/// (TR: «…, Rusya») adını taşır — Android'in `name_en = 'Moscow'` tam eşleşme
/// aramasıyla çakışmasın diye. iOS'ta EKRANDA ek gösterilmez (17.09.2026).
String cleanCityName(String s) => openFeedMode
    ? s.replaceFirst(RegExp(r',\s*(Russia|Rusya)$'), '')
    : s;
