import 'dart:math' as math;
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
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go('/onboarding');
      return;
    }

    final existing = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle();
    if (!mounted) return;

    if (existing == null) {
      context.go('/profile/setup');
    } else {
      context.go('/feed');
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
                      _Pill(color: AppColors.primaryRed, delay: Duration.zero),
                      const SizedBox(width: 16),
                      _Pill(color: AppColors.primaryBlue, isBlue: true, delay: Duration(milliseconds: 150)),
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

class _Pill extends StatefulWidget {
  final Color color;
  final bool isBlue;
  final Duration delay;
  const _Pill({required this.color, this.isBlue = false, this.delay = Duration.zero});
  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _float;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut))
    );
    _float = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut))
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut))
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = !widget.isBlue;
    final glowColor = isRed
        ? const Color(0xFFFF2D55)
        : const Color(0xFF2D7FFF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final floatOffset = math.sin(_float.value * math.pi) * (isRed ? -12.0 : 12.0);
        final glowRadius = 8.0 + _glow.value * 22.0;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: _scale.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3 + _glow.value * 0.6),
                    blurRadius: glowRadius,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 52,
                  height: 126,
                  child: Stack(
                    children: [
                      // Ana gövde
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.5),
                            radius: 1.2,
                            colors: isRed
                                ? const [Color(0xFFFF8080), Color(0xFFDD1122), Color(0xFF880008), Color(0xFFCC1122)]
                                : const [Color(0xFF8AB4FF), Color(0xFF1A44EE), Color(0xFF000FAA), Color(0xFF1A44EE)],
                            stops: const [0.0, 0.3, 0.65, 1.0],
                          ),
                        ),
                      ),
                      // Ana parlama
                      Positioned(
                        top: 9, left: 8,
                        child: Transform.rotate(
                          angle: -0.31,
                          child: Container(
                            width: 12, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      // İkinci parlama
                      Positioned(
                        top: 12, left: 18,
                        child: Transform.rotate(
                          angle: -0.31,
                          child: Container(
                            width: 6, height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      // Orta çizgi
                      Positioned(
                        top: 62, left: 0, right: 0,
                        child: Container(height: 1.5, color: Colors.black.withOpacity(0.45)),
                      ),
                      // Mavi için cam efekti
                      if (!isRed)
                        Positioned(
                          top: 63, left: 0, right: 0, bottom: 0,
                          child: Container(color: const Color(0xFF6496FF).withOpacity(0.1)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
