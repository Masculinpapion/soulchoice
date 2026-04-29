import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
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
import '../../features/discover/screens/discover_screen.dart';
import '../../features/messaging/screens/messages_list_screen.dart';
import '../../features/invitation/screens/invitation_detail_screen.dart';
import '../../features/invitation/screens/create_invitation_screen.dart';
import '../../features/invitation/screens/applicants_screen.dart';
import '../../features/invitation/screens/decision_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/delete_account_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/report_user_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // These routes always handle their own navigation.
      if (loc == '/auth/otp' ||
          loc == '/splash' ||
          loc == '/onboarding' ||
          loc == '/auth/phone') {
        return null;
      }

      final isAuthenticated =
          Supabase.instance.client.auth.currentUser != null;

      if (isAuthenticated && loc == '/auth/phone') return '/feed';
      if (!isAuthenticated) return '/splash';

      return null;
    },
    routes: [
      // ── Auth / Onboarding (root navigator) ─────────────────────────────
      GoRoute(path: '/splash', builder: (ctx, _) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),
      GoRoute(
          path: '/auth/phone', builder: (ctx, _) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),

      // ── Setup / Permissions (root navigator, shown over shell) ──────────
      GoRoute(
        path: '/profile/setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/profile/photos',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, state) =>
            PhotoUploadScreen(isEditing: state.extra == 'edit'),
      ),
      GoRoute(
        path: '/profile/selfie',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const SelfieScreen(),
      ),
      GoRoute(
        path: '/permissions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const PermissionsScreen(),
      ),

      // ── Invitation flows (root navigator, shown over shell) ─────────────
      GoRoute(
        path: '/invitation/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const CreateInvitationScreen(),
      ),
      GoRoute(
        path: '/invitation/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => InvitationDetailScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/invitation/:id/applicants',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => ApplicantsScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/invitation/:id/decision',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => DecisionScreen(
          invitationId: state.pathParameters['id']!,
        ),
      ),

      // ── Chat (root navigator) ───────────────────────────────────────────
      GoRoute(
        path: '/chat/:matchId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            ChatScreen(matchId: state.pathParameters['matchId']!),
      ),

      // ── Profile detail (root navigator, shown over shell) ───────────────
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            ProfileViewScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Settings (root navigator) ───────────────────────────────────────
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/delete-account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const AdminScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/report/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            ReportUserScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Shell with bottom nav ───────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Feed
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (ctx, _) => const FeedScreen(),
              ),
            ],
          ),
          // Branch 1: Discover
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (ctx, _) => const DiscoverScreen(),
              ),
            ],
          ),
          // Branch 2: Messages list
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (ctx, _) => const MessagesListScreen(),
              ),
            ],
          ),
          // Branch 3: Own profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-profile',
                builder: (ctx, _) {
                  final uid =
                      Supabase.instance.client.auth.currentUser?.id ?? '';
                  return ProfileViewScreen(userId: uid);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: Center(
        child: Text(
          'Sayfa bulunamadı',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
