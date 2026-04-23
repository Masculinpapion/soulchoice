import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Deep space glassmorphism background with soft violet + cyan ambient glows.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base: deep space blue-black
        Positioned.fill(
          child: Container(color: AppColors.bgBlack),
        ),
        // Violet glow — top left
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.75, -0.85),
                radius: 0.9,
                colors: [Color(0x368B5CF6), Colors.transparent],
              ),
            ),
          ),
        ),
        // Cyan glow — top right
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.85, -0.4),
                radius: 0.75,
                colors: [Color(0x2206B6D4), Colors.transparent],
              ),
            ),
          ),
        ),
        // Deep violet glow — bottom center (subtle depth)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 1.1),
                radius: 0.65,
                colors: [Color(0x1A6D28D8), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
