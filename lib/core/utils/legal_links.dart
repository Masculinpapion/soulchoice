import 'package:flutter/widgets.dart';

/// Hukuki sayfalar (Privacy / Terms / Oferta) — TEK KAYNAK soulchoice.app.
/// RU asıl ve bağlayıcı metin köktedir; EN/TR bilgilendirme çevirileri
/// /en/… ve /tr/… altındadır (18.08.2026). Uygulama, kullanıcının diline göre
/// doğru sayfayı açar; bilinmeyen dil → RU.
class LegalLinks {
  LegalLinks._();

  static const _base = 'https://soulchoice.app';

  static Uri privacy(BuildContext context) => _uri(context, 'privacy');
  static Uri terms(BuildContext context) => _uri(context, 'terms');
  static Uri oferta(BuildContext context, {String? anchor}) =>
      _uri(context, 'oferta', anchor: anchor);

  static Uri _uri(BuildContext context, String page, {String? anchor}) {
    final lang = Localizations.localeOf(context).languageCode;
    final prefix = (lang == 'en' || lang == 'tr') ? '/$lang' : '';
    return Uri.parse('$_base$prefix/$page${anchor != null ? '#$anchor' : ''}');
  }
}
