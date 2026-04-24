import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fadeIn = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      context.go('/onboarding');
      return;
    }

    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();
      if (!mounted) return;
      if (existing != null) {
        context.go('/feed');
      } else {
        try {
          await Supabase.instance.client.auth.refreshSession();
          if (!mounted) return;
          context.go('/profile/setup');
        } catch (_) {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          context.go('/onboarding');
        }
      }
    } catch (e) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/app_icon.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 36),
                  // Gradient brand name
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.primaryGradient.createShader(bounds),
                    child: Text(
                      'SoulChoice',
                      style: AppTextStyles.displayLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CHOOSE YOUR NIGHT',
                    style: AppTextStyles.monoSmall.copyWith(
                      letterSpacing: 5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

}
