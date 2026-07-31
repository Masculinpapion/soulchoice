import 'dart:async';
import 'dart:convert';
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
import 'core/services/presence_ping.dart';
import 'core/services/notification_cleaner.dart';
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
  // 31.07: BEKLEME YOK. await olduğu için ilk açılışta sistem izin diyaloğu
  // launch screen üstünde çıkıp runApp'i blokluyordu (kullanıcı cevaplayana
  // kadar boş ekran). İzin zaten onboarding'de açıklamalı ekranla isteniyor.
  unawaited(FirebaseMessaging.instance.requestPermission());
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

class _SoulChoiceAppState extends ConsumerState<SoulChoiceApp>
    with WidgetsBindingObserver {
  // Uygulama ÖN PLANDAYKEN gelen push çekmeceye düşmez (26.07 "gelmedi"
  // sanılan vaka) — kullanıcı kaçırmasın diye uygulama içi banner gösterilir.
  RemoteMessage? _bannerMsg;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    // Push'a dokunma → deep link. match_id taşıyan her bildirim (seçildin,
    // yeni mesaj) doğrudan ilgili sohbeti açar.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _routeFromPushData(m.data));
    FirebaseMessaging.onMessage.listen(_showInAppBanner);
    // Uygulama kapalıyken push'a dokunulup açıldıysa: sabit gecikme DEĞİL,
    // oturum yüklenene kadar bekle (31.07: 900 ms gerçek cihazda yetmiyordu —
    // currentUser null kalınca yönlendirme sessizce iptal olup feed'e düşüyordu).
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m == null) return;
      _openWhenSessionReady(m.data);
    });
    // iOS bildirim-tıklama köprüsü (01.08): FCM eklentisinin tap iletimi
    // iOS'ta delegate kurulum zamanlamasına takılıp kopabiliyor (tıklama
    // Dart'a hiç ulaşmıyor, kullanıcı feed'e düşüyordu). Natif AppDelegate
    // aynı olayı kendi kanalımızdan da yollar; olay iki kaynaktan gelirse
    // _routeFromPushData rota-dedupe ile teke indirir.
    const bridge = MethodChannel('com.soulchoice/notifications');
    bridge.setMethodCallHandler((call) async {
      if (call.method == 'pushTapped' && call.arguments is String) {
        _routeFromPushData(_bridgePushData(call.arguments as String));
      }
      return null;
    });
    bridge.invokeMethod<String>('getLaunchPush').then((json) {
      if (json == null) return;
      _openWhenSessionReady(_bridgePushData(json));
    }).catchError((_) {});
    // Panel-only online sinyali — kullanıcıya görünmez (31.07).
    PresencePing.instance.start();
    // iOS rozet: uygulama açılınca sıfırla (Android'de no-op).
    WidgetsBinding.instance.addObserver(this);
    NotificationCleaner.clearBadge();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) NotificationCleaner.clearBadge();
  }

  static Map<String, dynamic> _bridgePushData(String json) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      m.remove('aps');
      return m;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _openWhenSessionReady(Map<String, dynamic> data) async {
    // Soğuk açılış: 1) oturum diskten gelene, 2) splash yönlendirmesi bitene
    // kadar bekle. Splash sabit gecikmeyle go('/feed') yaptığı için erken
    // push edilen deep-link siliniyordu (31.07 denetim bulgusu Y1).
    for (var i = 0; i < 30; i++) {
      final hasSession = Supabase.instance.client.auth.currentUser != null;
      final loc = ref
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();
      if (hasSession && !loc.startsWith('/splash')) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    _routeFromPushData(data);
  }

  void _showInAppBanner(RemoteMessage m) {
    final n = m.notification;
    if (n == null || !mounted) return;
    // Kullanıcı zaten o sohbetteyse banner gürültü olur — realtime akış var.
    final matchId = m.data['match_id'];
    if (matchId is String && matchId.isNotEmpty) {
      final path = ref
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();
      if (path.contains('/chat/$matchId')) return;
    }
    setState(() => _bannerMsg = m);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerMsg = null);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _routeFromPushData(Map<String, dynamic> data) {
    // Oturum yoksa yönlendirme yapılmaz — giriş sonrası Mesajlar'da
    // "Yeni eşleşme" rozeti zaten en üstte gösterir.
    if (Supabase.instance.client.auth.currentUser == null) return;
    final type = data['type'] as String? ?? '';
    // Hedef rotayı seç; en sonda tek noktadan dedupe edilerek gidilir
    // (FCM eklentisi + natif köprü aynı tıklamayı ikisi birden iletebilir).
    String? target;
    var useGo = false;
    // Selfie reddi → doğrudan yeniden çekim ekranı; sebep banner'ı orada
    // (in-app listedeki routePath ile aynı rota). Onay push'u özel rota
    // istemez — normal açılış feed'e düşer.
    if (type == 'selfie_rejected') {
      target = '/profile/selfie';
    }
    // Yeni başvuru + seçim hatırlatması → başvuranlar ekranı
    // (26.07 iOS turu: feed'e düşüyordu; selection_reminder dalı 31.07 denetimi)
    final invitationId = data['invitation_id'];
    if (target == null &&
        (type == 'new_application' || type == 'selection_reminder') &&
        invitationId is String &&
        invitationId.isNotEmpty) {
      target = '/invitation/$invitationId/applicants';
    }
    // Ödeme/abonelik push'ları → abonelik ekranı (31.07 denetimi: dalı yoktu,
    // dokununca hiçbir şey olmuyordu; in-app liste zaten /subscription açıyor)
    if (target == null && type.startsWith('premium_')) {
      target = '/subscription';
    }
    // Askı bildirimi → askı ekranı (router guard'ı zaten oraya kilitler)
    if (target == null && type == 'account_suspended') {
      target = '/suspended';
      useGo = true;
    }
    if (target == null) {
      final matchId = data['match_id'];
      if (matchId is! String || matchId.isEmpty) return;
      target = '/chat/$matchId';
    }
    final router = ref.read(routerProvider);
    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    if (loc == target) return; // çift kaynak dedupe — zaten hedefteyiz
    if (useGo) {
      router.go(target);
    } else {
      router.push(target);
    }
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
        child: Stack(
          children: [
            if (child != null) child,
            // Foreground push banner'ı — dokun: ilgili ekrana git; yukarı
            // kaydır: kapat; 4 sn'de kendiliğinden kaybolur.
            if (_bannerMsg != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {
                      final m = _bannerMsg!;
                      setState(() => _bannerMsg = null);
                      _routeFromPushData(m.data);
                    },
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < 0) {
                        setState(() => _bannerMsg = null);
                      }
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xF20D0D16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.14)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _bannerMsg!.notification?.title ?? 'SoulChoice',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if ((_bannerMsg!.notification?.body ?? '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _bannerMsg!.notification!.body!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
