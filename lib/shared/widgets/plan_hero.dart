import 'package:flutter/material.dart';

import '../../core/theme/aurora_theme.dart';
import '../../data/models/invitation_model.dart';

/// «Önce plan» kart zemini (iOS App Store paketi, 09.09.2026).
///
/// Kişi fotoğrafı yerine kategori sahnesi: kart ilk bakışta PLANI anlatır,
/// kişi yalnız üstteki küçük avatar pilinde görünür. Yalnız `planFirstMode`
/// (iOS) dallarında kullanılır — Android kart zemini değişmez.
class PlanHero extends StatelessWidget {
  final InvitationCategory category;
  final double glyphSize;
  final Alignment alignment;

  const PlanHero({
    super.key,
    required this.category,
    this.glyphSize = 72,
    this.alignment = const Alignment(0, -0.35),
  });

  @override
  Widget build(BuildContext context) {
    final Widget glyph = category == InvitationCategory.bar
        ? Image.asset('assets/icons/bar.png', width: glyphSize, height: glyphSize)
        : category == InvitationCategory.concert
            ? Image.asset('assets/icons/music.png',
                width: glyphSize * 0.92,
                height: glyphSize * 0.92,
                color: AuroraTheme.auroraRed)
            : Text(category.emoji,
                style: TextStyle(fontSize: glyphSize, height: 1.0));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0510), Color(0xFF0A0B1A), AuroraTheme.bgDeep],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Yumuşak ışık halesi — glifin arkasında
          Positioned.fill(
            child: Align(
              alignment: alignment,
              child: Container(
                width: glyphSize * 2.2,
                height: glyphSize * 2.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AuroraTheme.auroraRed.withOpacity(0.26),
                      AuroraTheme.auroraBlue.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: Align(alignment: alignment, child: glyph)),
        ],
      ),
    );
  }
}
