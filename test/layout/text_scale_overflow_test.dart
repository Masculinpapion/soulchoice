// 03.09.2026 — Metin ölçeği / küçük ekran TAŞMA testleri (kalite teşhisi: 23.08 testçi paketi
// sınıfı — S22 1.3×, S10+ 1.7× büyütmede alt bar iki satıra düşüyor, buton fold altında kalıyordu;
// hiçbir mevcut test tipi yakalayamazdı). Supabase'e initState'te dokunmayan giriş/onboarding
// ekranları, iki cihaz boyutu × üç metin ölçeği × RU (en uzun metinler) matrisinde çizilir;
// bir RenderFlex taşması Flutter test motorunda exception olarak yükselir → test kırmızı.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/core/theme/app_theme.dart';
import 'package:soulchoice/features/auth/screens/otp_screen.dart';
import 'package:soulchoice/features/auth/screens/phone_screen.dart';
import 'package:soulchoice/features/auth/screens/suspended_screen.dart';
import 'package:soulchoice/features/onboarding/screens/onboarding_screen.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class _Device {
  const _Device(this.name, this.w, this.h, this.dpr);
  final String name;
  final double w, h, dpr;
}

const _devices = [
  _Device('S10+ (360x760)', 360, 760, 2.5),
  _Device('S24 (412x915)', 412, 915, 2.6),
];
const _scales = [1.0, 1.3, 1.7];

final _screens = <String, Widget Function()>{
  'PhoneScreen': () => const PhoneScreen(),
  'OtpScreen': () => const OtpScreen(phone: '+79991112233'),
  'OnboardingScreen': () => const OnboardingScreen(),
  'SuspendedScreen': () => const SuspendedScreen(),
};

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en'), Locale('tr')],
        // main.dart ile aynı kısıt (23.08 testçi paketi): sistem 1.7× isterse uygulama 1.15× çizer.
        // Matris yine 1.0/1.3/1.7 sistem değeriyle koşar; kısıtın çalıştığı da böylece doğrulanır.
        builder: (context, c) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
          child: c ?? const SizedBox(),
        ),
        home: child,
      ),
    );

Future<void> _loadRealFonts() async {
  // Test motoru varsayılan olarak kare 'Ahem' fontu kullanır (her glif eşit genişlik) —
  // gerçek Manrope/Fraunces/JetBrainsMono metrikleri yüklenmezse taşma sonuçları yanıltır.
  const fonts = {
    'Manrope': ['assets/fonts/Manrope.ttf'],
    'Fraunces': ['assets/fonts/Fraunces.ttf', 'assets/fonts/Fraunces-Italic.ttf'],
    'JetBrainsMono': ['assets/fonts/JetBrainsMono.ttf', 'assets/fonts/JetBrainsMono-Italic.ttf'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadRealFonts);
  for (final entry in _screens.entries) {
    for (final d in _devices) {
      for (final scale in _scales) {
        testWidgets('${entry.key} taşmaz — ${d.name} × ${scale}x', (tester) async {
          tester.view.physicalSize = Size(d.w * d.dpr, d.h * d.dpr);
          tester.view.devicePixelRatio = d.dpr;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(_wrap(entry.value()));
          await tester.pump(const Duration(milliseconds: 600));
          final err = tester.takeException();
          // Ekranı kaldır: yeniden-gönder sayacı gibi zamanlayıcılar dispose'da kapanır
          // (aksi hâlde test 'Timer still pending' ile düşer — taşma değildir).
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
          expect(err, isNull,
              reason: '${entry.key} ${d.name} ${scale}x: layout hatası/taşma: $err');
        });
      }
    }
  }
}
