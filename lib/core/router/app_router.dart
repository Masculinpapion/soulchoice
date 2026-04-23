import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/permissions_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/photo_upload_screen.dart';
import '../../features/profile/screens/selfie_screen.dart';
import '../../features/profile/screens/profile_view_screen.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/invitation/screens/invitation_detail_screen.dart';
import '../../features/invitation/screens/create_invitation_screen.dart';
import '../../features/invitation/screens/applicants_screen.dart';
import '../../features/invitation/screens/decision_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/delete_account_screen.dart';
import '../../features/admin/screens/admin_screen.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // These routes always handle their own navigation.
      if (loc == '/auth/otp' || loc == '/splash' || loc == '/onboarding' || loc == '/auth/phone') {
        debugPrint('[R] loc=$loc → null (exempt)');
        return null;
      }

      final isAuthenticated =
          Supabase.instance.client.auth.currentUser != null;

      // Authenticated users going back to /auth/phone — send to feed.
      if (isAuthenticated && loc == '/auth/phone') {
        debugPrint('[R] loc=$loc, auth=true → /feed');
        return '/feed';
      }

      // Unauthenticated users trying to reach protected routes — send to splash.
      if (!isAuthenticated) {
        debugPrint('[R] loc=$loc, auth=false → /splash');
        return '/splash';
      }

      debugPrint('[R] loc=$loc, auth=true → null');
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (ctx, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),
      GoRoute(path: '/auth/phone', builder: (ctx, _) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) {
          final phone = state.extra as String;
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(path: '/profile/setup', builder: (ctx, _) => const ProfileSetupScreen()),
      GoRoute(path: '/profile/photos', builder: (ctx, _) => const PhotoUploadScreen()),
      GoRoute(path: '/profile/selfie', builder: (ctx, _) => const SelfieScreen()),
      GoRoute(path: '/permissions', builder: (ctx, _) => const PermissionsScreen()),
      GoRoute(path: '/feed', builder: (ctx, _) => const FeedScreen()),
      GoRoute(
        path: '/invitation/create',
        builder: (ctx, _) => const CreateInvitationScreen(),
      ),
      GoRoute(
        path: '/invitation/:id',
        builder: (_, state) => InvitationDetailScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/invitation/:id/applicants',
        builder: (_, state) => ApplicantsScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/invitation/:id/decision',
        builder: (_, state) => DecisionScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (_, state) => ChatScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => ProfileViewScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
      GoRoute(path: '/settings/delete-account', builder: (ctx, _) => const DeleteAccountScreen()),
      GoRoute(path: '/admin', builder: (ctx, _) => const AdminScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Center(
        child: Text(
          'Sayfa bulunamadı',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
