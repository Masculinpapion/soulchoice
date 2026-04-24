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
                  // 3D glossy pills — kırmızı (Ismarlıyorum) + mavi cam (İstiyorum)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Pill(color: AppColors.primaryRed),
                      const SizedBox(width: 16),
                      _Pill(color: AppColors.primaryBlue, glass: true),
                    ],
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

class _Pill extends StatelessWidget {
  final Color color;
  final bool glass;

  const _Pill({required this.color, this.glass = false});

  @override
  Widget build(BuildContext context) {
    const w = 42.0;
    const h = 104.0;
    const radius = 21.0;

    final dark = Color.lerp(color, Colors.black, 0.42)!;
    final darkEdge = Color.lerp(color, Colors.black, 0.28)!;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 26,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 14,
            offset: const Offset(3, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 1. Silindir vücut: sol koyu → merkez parlak → sağ koyu
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [dark, color, color, darkEdge],
                    stops: const [0.0, 0.28, 0.62, 1.0],
                  ),
                ),
              ),
            ),
            // 2. Alt karartma
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(glass ? 0.18 : 0.32),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            // 3. Cam gövde parlaklığı (mavi hap için)
            if (glass)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.20, 0.44, 0.66, 1.0],
                    ),
                  ),
                ),
              ),
            // 4. Sol speküler highlight şeridi
            Positioned(
              left: w * 0.13,
              top: h * 0.09,
              width: w * 0.19,
              height: h * 0.63,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.10),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(glass ? 0.75 : 0.58),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 5. Üst parlak nokta
            Positioned(
              left: w * 0.15,
              top: h * 0.055,
              width: w * 0.22,
              height: w * 0.22,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(glass ? 0.95 : 0.88),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
