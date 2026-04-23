import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Deep glassmorphism background with soft red + blue ambient glows.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base: deep black
        Positioned.fill(
          child: Container(color: AppColors.bgBlack),
        ),
        // Red glow — top left
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.75, -0.85),
                radius: 0.9,
                colors: [Color(0x30E63946), Colors.transparent],
              ),
            ),
          ),
        ),
        // Blue glow — top right
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.85, -0.4),
                radius: 0.75,
                colors: [Color(0x264A90E2), Colors.transparent],
              ),
            ),
          ),
        ),
        // Subtle warm glow — bottom center
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 1.1),
                radius: 0.65,
                colors: [Color(0x1AE63946), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
