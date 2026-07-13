import 'package:flutter/material.dart';

/// Klavye-güvenli Scaffold — düz [Scaffold] yerine metin girişli her ekranda
/// bunu kullan.
///
/// `resizeToAvoidBottomInset` BİLEREK dışarı açılmaz ve her zaman `true`'dur:
/// klavye açıldığında gövde küçülür, böylece alttaki CTA butonu klavyenin
/// üstünde erişilebilir kalır. (iOS'ta sayısal/çok-satırlı klavyede "done/enter"
/// tuşu yoktur; `resizeToAvoidBottomInset: false` verilirse buton klavyenin
/// altında kalıp ekran kilitlenir — bu widget o tuzağı kökten engeller.)
///
/// Sabit yükseklikli (Spacer tabanlı) içerikler küçük ekranlarda taşmasın diye
/// gövdeyi [ScKeyboardFill] ile sar.
class ScScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  const ScScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: true,
      body: body,
    );
  }
}

// NOT (13.07.2026): ScKeyboardFill kaldırıldı. "İçeriği IntrinsicHeight ile
// doldur, sığmazsa kaydır" deseni CTA'yı da scroll'un içine aldığından klavye
// açılınca buton katlama çizgisinin altında kalıyordu. Doğru desen: Column +
// Expanded(SingleChildScrollView(içerik)) + scroll DIŞINDA alta sabit CTA
// (bkz. phone_screen / otp_screen / edit_*_screen).
