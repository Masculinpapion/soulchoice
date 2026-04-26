import 'package:flutter/material.dart';
import '../../core/widgets/aurora/aurora_background.dart';

/// Backward-compatible wrapper — tüm ekranlar bu ismi kullanmaya devam eder,
/// içeride AuroraBackground'ı devreder.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AuroraBackground(child: child);
}
