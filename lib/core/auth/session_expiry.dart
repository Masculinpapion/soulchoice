/// Oturumun KENDİLİĞİNDEN düşmesi ile kullanıcının bilinçli çıkışını ayırır.
/// signedOut geldiğinde manualLogout değilse expired=true olur; telefon
/// ekranı bunu bir kez gösterip temizler (madde S — görünür re-login).
class SessionExpiry {
  static bool expired = false;
  static bool manualLogout = false;
}
