import 'dart:io';

import 'package:smart_auth/smart_auth.dart';

/// Android SMS Retriever tabanlı OTP otomatik doldurma.
///
/// Play, RuStore ve debug build'lerinin imza sertifikaları (dolayısıyla
/// Retriever hash'leri) FARKLI olduğundan hash sabitlenmez: istemci kendi
/// hash'ini çalışma anında alıp OTP isteğiyle sunucuya gönderir, sunucu SMS
/// metninin sonuna ekler. Sistem hash'i eşleşen SMS'i uygulamaya izinsiz ve
/// diyalogsuz iletir. GMS olmayan cihazlarda tüm çağrılar sessizce null döner —
/// elle giriş her zaman çalışır.
class OtpAutofill {
  OtpAutofill._();

  static final SmartAuth _auth = SmartAuth.instance;
  static String? _cachedSignature;

  /// SMS gönderim isteğine eklenecek 11 karakterlik imza hash'i (yalnız Android).
  static Future<String?> appSignature() async {
    if (!Platform.isAndroid) return null;
    if (_cachedSignature != null) return _cachedSignature;
    final res = await _auth.getAppSignature();
    final sig = res.data;
    if (sig != null && sig.isNotEmpty) _cachedSignature = sig;
    return _cachedSignature;
  }

  /// Hash'li SMS gelene kadar dinler (sistem ~5 dk sonra kendisi kapatır);
  /// SMS metnindeki ilk 4 haneli sayıyı döndürür (kod hash'ten önce geldiği
  /// için hash içindeki olası rakamlar karışmaz).
  static Future<String?> waitForSmsCode() async {
    if (!Platform.isAndroid) return null;
    final res = await _auth.getSmsWithRetrieverApi(matcher: r'\d{4}');
    return res.data?.code;
  }

  /// Ekrandan çıkarken dinleyiciyi bırak.
  static Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    await _auth.removeSmsRetrieverApiListener();
  }
}
