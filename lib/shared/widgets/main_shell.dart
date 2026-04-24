import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _GlassNavBar(
        currentBranchIndex: navigationShell.currentIndex,
        onBranchTap: (branchIndex) {
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        onFabTap: () => context.push('/invitation/create'),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int currentBranchIndex;
  final ValueChanged<int> onBranchTap;
  final VoidCallback onFabTap;

  const _GlassNavBar({
    required this.currentBranchIndex,
    required this.onBranchTap,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 72 + bottomPad,
          padding: EdgeInsets.only(bottom: bottomPad),
          decoration: const BoxDecoration(
            color: Color(0x18FFFFFF),
            border: Border(
              top: BorderSide(color: AppColors.glassBorder),
            ),
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
              // FAB (center)
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: onFabTap,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gradientStart.withOpacity(0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: AppColors.gradientEnd.withOpacity(0.20),
                            blurRadius: 20,
                            offset: const Offset(4, 0),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
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
          splashColor: AppColors.gradientStart.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isActive
                    ? ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.primaryGradient.createShader(b),
                        child: Icon(activeIcon,
                            color: Colors.white, size: 22),
                      )
                    : Icon(icon,
                        color: AppColors.textTertiary, size: 22),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppTextStyles.monoSmall.copyWith(
                    color: isActive
                        ? AppColors.gradientStart
                        : AppColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
