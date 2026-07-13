import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
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
      duration: const Duration(milliseconds: 1400),
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
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go('/onboarding');
      return;
    }

    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      context.go(existing == null ? '/profile/setup' : '/feed');
    } catch (_) {
      // Ağ yok/yavaş: session var demek kullanıcı daha önce giriş yapmış →
      // feed'e geç (feed kendi offline/hata durumunu gösterir). Sonsuz splash
      // YASAK — kullanıcı "bozuk app" sanmasın.
      if (mounted) context.go('/feed');
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
      backgroundColor: AuroraTheme.bgDeep,
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
                      _Pill(delay: Duration.zero),
                      const SizedBox(width: 16),
                      _Pill(isBlue: true, delay: Duration.zero),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Image.asset(
                    'assets/branding/soulchoice_wordmark.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CHOOSE YOUR MOMENT',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 5,
                      color: AuroraTheme.textMuted,
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
  final bool isBlue;
  final Duration delay;
  const _Pill({this.isBlue = false, this.delay = Duration.zero});
  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final floatY = widget.isBlue
            ? -math.sin(t * 2 * math.pi) * 12.0
            : math.sin(t * 2 * math.pi) * 12.0;
        final glowOpacity = 0.18 + t * 0.14;
        final glowColor = widget.isBlue
            ? const Color(0xFF2D7FFF)
            : const Color(0xFFFF2D55);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Container(
            width: 54,
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(glowOpacity),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(3, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                children: [
                  // Ana gövde — derin 3D gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isBlue
                            ? const [
                                Color(0xFF5588DD),
                                Color(0xFF1133BB),
                                Color(0xFF001088),
                                Color(0xFF0A2299),
                                Color(0xFF1133BB),
                              ]
                            : const [
                                Color(0xFFDD4444),
                                Color(0xFFBB1111),
                                Color(0xFF880006),
                                Color(0xFF991100),
                                Color(0xFFBB1111),
                              ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                  // Kenar karartma (derinlik)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                  // Üst parlama (ana yansıma)
                  Positioned(
                    top: 8, left: 7,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        width: 14,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.55),
                              Colors.white.withOpacity(0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // İkincil ince parlama
                  Positioned(
                    top: 14, left: 24,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        width: 5,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  // Orta bant (kapsül birleşim çizgisi)
                  Positioned(
                    top: 63, left: 0, right: 0,
                    child: Container(
                      height: 2,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  // Alt yarı biraz daha koyu
                  Positioned(
                    top: 65, left: 0, right: 0, bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Alt küçük parlama
                  Positioned(
                    bottom: 10, right: 8,
                    child: Container(
                      width: 8,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

