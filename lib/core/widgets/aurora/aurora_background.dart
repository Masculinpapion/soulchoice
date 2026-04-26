import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/aurora_theme.dart';

/// Animasyonlu aurora arka plan — kırmızı + mavi glowlar yavaşça hareket eder.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AuroraTheme.bgDeep),
            // Kırmızı glow — sol üst, yavaşça kayıyor
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(t * 2 * math.pi) * 0.3 - 0.65,
                    -1.0 + math.cos(t * 2 * math.pi) * 0.12,
                  ),
                  radius: 1.4,
                  colors: [
                    AuroraTheme.auroraRed.withOpacity(0.22),
                    AuroraTheme.auroraViolet.withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.75],
                ),
              ),
            ),
            // Mavi glow — sağ, karşı yönde hareket
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.65 + math.sin(t * 2 * math.pi + math.pi) * 0.2,
                    -0.3 + math.cos(t * 2 * math.pi) * 0.15,
                  ),
                  radius: 1.1,
                  colors: [
                    AuroraTheme.auroraBlue.withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
            // Alt hafif sıcak glow
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 1.1),
                  radius: 0.6,
                  colors: [
                    AuroraTheme.auroraRed.withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
