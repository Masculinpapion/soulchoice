import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform sorgularının web-güvenli hâli.
///
/// `dart:io`'nun `Platform` sınıfı web'de derlenir ama ÇAĞRILDIĞINDA fırlatır —
/// tarayıcı demosu (üniversite test kanalı, 01.08) beyaz ekranda kalıyordu.
/// Web'de iOS DEĞİL sayılır: ödeme/paywall akışı zaten web'de "link" modudur.
bool get isIOSDevice => !kIsWeb && Platform.isIOS;

/// Sunucuya yazılan kaynak etiketi (`users.last_platform`, ödeme `source`).
String get platformTag => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
