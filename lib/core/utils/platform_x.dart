import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

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

/// Kurulum kaynağı etiketi (`users.install_source`, AppMetrica profil özniteliği).
/// 26.09.2026 (Play yayını): Telegram «yeni kullanıcı» mesajı ve huni, kullanıcının
/// hangi mağazadan geldiğini göstersin. package_info_plus `installerStore`:
/// Android → yükleyici paket adı, iOS → `com.apple` / `com.apple.testflight`,
/// geliştirici kurulumunda null. Hata ürün akışını bozmaz → 'unknown'.
Future<String> installSourceTag() async {
  if (kIsWeb) return 'web';
  try {
    final store = (await PackageInfo.fromPlatform()).installerStore;
    switch (store) {
      case 'com.android.vending':
        return 'play';
      case 'ru.vk.store':
        return 'rustore';
      case 'com.apple':
        return 'appstore';
      case 'com.apple.testflight':
        return 'testflight';
      case null:
      case '':
        return Platform.isIOS ? 'unknown' : 'apk';
      case 'com.android.shell': // adb install (emülatör kanıtı 26.09: shell döndü)
        return 'apk';
      default:
        // com.google.android.packageinstaller, com.android.packageinstaller,
        // dosya yöneticileri → doğrudan APK; başka mağaza (AppGallery, GetApps,
        // Galaxy Store) ham paket adıyla kalır ki huni raporunda görünsün.
        return store.contains('packageinstaller') ? 'apk' : 'other:$store';
    }
  } catch (_) {
    return 'unknown';
  }
}
