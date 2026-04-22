import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.bgBlack,
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.9),
                radius: 1.0,
                colors: [Color(0x40E63946), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.9, -0.4),
                radius: 0.9,
                colors: [Color(0x334A90E2), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 1.0),
                radius: 0.8,
                colors: [Color(0x26D4A574), Colors.transparent],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
