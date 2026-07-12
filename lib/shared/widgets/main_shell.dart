import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/aurora_theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _AuroraNavBar(
        currentBranchIndex: navigationShell.currentIndex,
        onBranchTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        onFabTap: () => context.push('/invitation/create'),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aurora bottom nav bar — floating pill, FAB yüksekte
// ─────────────────────────────────────────────────────────────────────────────

class _AuroraNavBar extends StatelessWidget {
  final int currentBranchIndex;
  final ValueChanged<int> onBranchTap;
  final VoidCallback onFabTap;

  const _AuroraNavBar({
    required this.currentBranchIndex,
    required this.onBranchTap,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pill nav
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  // Düz %75 dolgu koyu içerikte camı boğuyordu (Обзор'da "siyah
                  // blok" algısı); dikey tint: üstten kartlar süzülür, ikon
                  // bölgesi (alt yarı) kontrastını korur. Blur maliyeti aynı.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0A0E).withOpacity(0.15),
                      const Color(0xFF0A0A0E).withOpacity(0.45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: AuroraTheme.auroraRed.withOpacity(0.08),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: l10n.nav_home,
                      isActive: currentBranchIndex == 0,
                      onTap: () => onBranchTap(0),
                    ),
                    _NavItem(
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore_rounded,
                      label: l10n.nav_discover,
                      isActive: currentBranchIndex == 1,
                      onTap: () => onBranchTap(1),
                    ),
                    // FAB boşluk
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: l10n.nav_messages,
                      isActive: currentBranchIndex == 2,
                      onTap: () => onBranchTap(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: l10n.nav_profile,
                      isActive: currentBranchIndex == 3,
                      onTap: () => onBranchTap(3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FAB — ortada, pill'in üstüne çıkıyor
          Positioned(
            top: -5,
            child: GestureDetector(
              onTap: onFabTap,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AuroraTheme.redBlueGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AuroraTheme.auroraRed.withOpacity(0.55),
                      blurRadius: 32,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          splashColor: AuroraTheme.auroraRed.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isActive
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(Rect.fromLTRB(b.left - 4, b.top - 2, b.right + 14, b.bottom + 4)),
                        child: Icon(activeIcon,
                            color: Colors.white, size: 22),
                      )
                    : Icon(icon,
                        color: Colors.white.withOpacity(0.35), size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: isActive
                        ? AuroraTheme.auroraRed
                        : Colors.white.withOpacity(0.30),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
