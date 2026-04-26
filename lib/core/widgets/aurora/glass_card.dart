import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/aurora_theme.dart';

class AuroraGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final double radius;
  final Color? borderColor;
  final List<BoxShadow>? customShadow;
  final VoidCallback? onTap;

  const AuroraGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.radius = AuroraTheme.radiusInfoCard,
    this.borderColor,
    this.customShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? AuroraTheme.glassBorder,
              width: 1,
            ),
            boxShadow: customShadow,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: card,
        ),
      );
    }
    return card;
  }
}
