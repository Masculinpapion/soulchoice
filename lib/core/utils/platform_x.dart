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

/// iOS App Store deneyimi: «önce plan» sunumu (09.09.2026, Apple 4.3(b) paketi).
///
/// Derleme anında platforma bağlıdır; UZAKTAN bayrakla DEĞİŞTİRİLMEZ (Apple
/// onayından sonra akışı değiştirmek 2.3.1 bait-and-switch sayılır). Android
/// ve web bu dalları hiç çalıştırmaz — RuStore/Play davranışı aynen kalır.
/// Kapsam: kayıt öncesi mekanik hikâyesi, sihirbazda cinsiyet/yaş aralığı
/// adımı yok (cinsiyet ilk plan/başvuruda sorulur), kartlarda plan öne çıkar.
bool get planFirstMode => isIOSDevice || _planFirstPreview;

/// YALNIZ yerel önizleme: `flutter run --dart-define=PLAN_FIRST=true` ile
/// Android emülatöründe iOS sunumuna bakmak için (simülatör çalışma zamanı
/// yokken, 09.09). Derleme sabiti — mağaza paketlerinde verilmez, varsayılan
/// false; uzaktan değiştirilemez.
const bool _planFirstPreview = bool.fromEnvironment('PLAN_FIRST');
