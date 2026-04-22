import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
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
    _fadeIn = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      context.go('/feed');
    } else {
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
                  // 3D Pill placeholders — replace with Lottie
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Pill(color: AppColors.red, glowColor: AppColors.redGlow),
                      const SizedBox(width: 12),
                      _Pill(color: AppColors.blue, glowColor: AppColors.blueGlow),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SoulChoice',
                    style: AppTextStyles.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CHOOSE YOUR NIGHT',
                    style: AppTextStyles.monoSmall.copyWith(
                      letterSpacing: 4,
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
  final Color glowColor;

  const _Pill({required this.color, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 24, spreadRadius: 4),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.9),
            color,
            color.withOpacity(0.7),
          ],
        ),
      ),
    );
  }
}
