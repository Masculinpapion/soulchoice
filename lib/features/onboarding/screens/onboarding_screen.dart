import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final pages = [
      _OnboardingPageData(
        pillColor: AppColors.red,
        pillGlow: AppColors.redGlow,
        title: l10n.onboarding_1_title,
        subtitle: l10n.onboarding_1_desc,
      ),
      _OnboardingPageData(
        pillColor: AppColors.blue,
        pillGlow: AppColors.blueGlow,
        title: l10n.onboarding_2_title,
        subtitle: l10n.onboarding_2_desc,
      ),
      _OnboardingPageData(
        pillColor: AppColors.gold,
        pillGlow: AppColors.gold,
        title: l10n.onboarding_3_title,
        subtitle: l10n.onboarding_3_desc,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: pages.length,
                  itemBuilder: (_, i) => _OnboardingPage(data: pages[i]),
                ),
              ),
              Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == i ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.red
                              : AppColors.glassBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Gradient buton — horizontal: 24 padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _currentPage < pages.length - 1
                        ? ScButton(
                            label: l10n.btn_continue,
                            onPressed: () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                          )
                        : ScButton(
                            label: l10n.onboarding_start_button,
                            onPressed: () => context.go('/auth/phone'),
                          ),
                  ),
                  // Atla — sadece ilk 2 sayfada göster
                  if (_currentPage < pages.length - 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/auth/phone'),
                      child: Text(l10n.onboarding_skip,
                          style: AppTextStyles.bodyMedium),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _OnboardingPageData {
  final Color pillColor;
  final Color pillGlow;
  final String title;
  final String subtitle;

  const _OnboardingPageData({
    required this.pillColor,
    required this.pillGlow,
    required this.title,
    required this.subtitle,
  });
}

// ─── Page widget ─────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Pill3D(color: data.pillColor),
          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              data.title,
              style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              data.subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gerçek 3D silindir hap ───────────────────────────────────────────────────

class _Pill3D extends StatelessWidget {
  final Color color;
  const _Pill3D({required this.color});

  @override
  Widget build(BuildContext context) {
    const w = 48.0;
    const h = 114.0;
    const radius = 24.0;

    final dark = Color.lerp(color, Colors.black, 0.42)!;
    final darkEdge = Color.lerp(color, Colors.black, 0.28)!;
    final isBlue = color == AppColors.blue;
    final isGold = color == AppColors.gold;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isGold ? 0.40 : 0.55),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(3, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [dark, color, color, darkEdge],
                    stops: const [0.0, 0.28, 0.62, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(isBlue ? 0.18 : 0.32),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            if (isBlue || isGold)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.20, 0.44, 0.66, 1.0],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: w * 0.13,
              top: h * 0.09,
              width: w * 0.19,
              height: h * 0.63,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.10),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(isBlue ? 0.75 : 0.58),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: w * 0.15,
              top: h * 0.055,
              width: w * 0.22,
              height: w * 0.22,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(isBlue ? 0.95 : 0.88),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
