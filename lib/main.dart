import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/constants/supabase_constants.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _saveFcmToken() async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', uid);
  } catch (_) {}
}

Future<void> _appInit() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  AppMetrica.activate(const AppMetricaConfig('7d2ff52b-8262-411f-8b24-b3f5f52c17eb'));

  timeago.setLocaleMessages('tr', timeago.TrMessages());
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  _saveFcmToken();
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) _saveFcmToken();
  });
  FirebaseMessaging.instance.onTokenRefresh.listen((_) => _saveFcmToken());

  runApp(const ProviderScope(child: SoulChoiceApp()));
}

Future<void> main() async {
  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: _appInit,
    );
  } else {
    await _appInit();
  }
}

class SoulChoiceApp extends ConsumerWidget {
  const SoulChoiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'SoulChoice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale('tr'),
      ],
    );
  }
}
