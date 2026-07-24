import 'dart:io';
import 'dart:ui';

import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/constants/supabase_constants.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/push_token.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// FCM token kaydı core/services/push_token.dart'a taşındı (24.07):
// kayıt akışının sonunda da çağrılması gerekiyor (yeni kullanıcı push bug'ı).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  AppMetrica.activate(
    const AppMetricaConfig('7d2ff52b-8262-411f-8b24-b3f5f52c17eb'),
  );

  timeago.setLocaleMessages('tr', timeago.TrMessages());
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  savePushToken();
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) savePushToken();
  });
  FirebaseMessaging.instance.onTokenRefresh.listen((_) => savePushToken());

  runApp(const ProviderScope(child: SoulChoiceApp()));
}

class SoulChoiceApp extends ConsumerStatefulWidget {
  const SoulChoiceApp({super.key});

  @override
  ConsumerState<SoulChoiceApp> createState() => _SoulChoiceAppState();
}

class _SoulChoiceAppState extends ConsumerState<SoulChoiceApp> {
  @override
  void initState() {
    super.initState();
    // Push'a dokunma → deep link. match_id taşıyan her bildirim (seçildin,
    // yeni mesaj) doğrudan ilgili sohbeti açar.
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromPush);
    // Uygulama kapalıyken push'a dokunulup açıldıysa: splash/auth
    // yönlendirmesi otursun diye kısa gecikmeyle gir.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m == null) return;
      Future.delayed(const Duration(milliseconds: 900), () => _openFromPush(m));
    });
  }

  void _openFromPush(RemoteMessage m) {
    // Oturum yoksa yönlendirme yapılmaz — giriş sonrası Mesajlar'da
    // "Yeni eşleşme" rozeti zaten en üstte gösterir.
    if (Supabase.instance.client.auth.currentUser == null) return;
    // Selfie reddi → doğrudan yeniden çekim ekranı; sebep banner'ı orada
    // (in-app listedeki routePath ile aynı rota). Onay push'u özel rota
    // istemez — normal açılış feed'e düşer.
    if (m.data['type'] == 'selfie_rejected') {
      ref.read(routerProvider).push('/profile/selfie');
      return;
    }
    final matchId = m.data['match_id'];
    if (matchId is! String || matchId.isEmpty) return;
    ref.read(routerProvider).push('/chat/$matchId');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'SoulChoice',
      debugShowCheckedModeBanner: false,
      // Boş alana dokununca klavyeyi kapat — tüm ekranlarda tutarlı,
      // yeni eklenen ekranlar da otomatik kapsanır.
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child,
      ),
      theme: AppTheme.dark,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en'), Locale('tr')],
    );
  }
}
