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

/// Gövdeyi "sığarsa ekranı doldur, sığmazsa kaydır" desenine sokar.
///
/// [Spacer]/sabit yükseklik kullanan ekranlarda ([ScScaffold] ile birlikte),
/// klavye açılıp gövde küçülünce içeriğin taşmasını (overflow) önler: içerik
/// sığdığı sürece tam ekranı doldurur, sığmazsa kaydırılabilir olur.
class ScKeyboardFill extends StatelessWidget {
  final Widget child;

  const ScKeyboardFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
