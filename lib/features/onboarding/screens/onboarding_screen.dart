import 'dart:math' as math;
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
          _Pill(color: data.pillColor, isBlue: data.pillColor == AppColors.blue, delay: Duration.zero),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                data.title,
                style: AppTextStyles.displayMedium.copyWith(height: 1.35),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                data.subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aurora animasyonlu hap ───────────────────────────────────────────────────

class _Pill extends StatefulWidget {
  final Color color;
  final bool isBlue;
  final Duration delay;
  const _Pill({required this.color, this.isBlue = false, this.delay = Duration.zero});
  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _float;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut))
    );
    _float = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut))
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut))
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = !widget.isBlue;
    final glowColor = isRed
        ? const Color(0xFFFF2D55)
        : const Color(0xFF2D7FFF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final floatOffset = math.sin(_float.value * math.pi) * (isRed ? -12.0 : 12.0);
        final glowRadius = 8.0 + _glow.value * 22.0;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: _scale.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3 + _glow.value * 0.6),
                    blurRadius: glowRadius,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 52,
                  height: 126,
                  child: Stack(
                    children: [
                      // Ana gövde
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.5),
                            radius: 1.2,
                            colors: isRed
                                ? const [Color(0xFFFF8080), Color(0xFFDD1122), Color(0xFF880008), Color(0xFFCC1122)]
                                : const [Color(0xFF8AB4FF), Color(0xFF1A44EE), Color(0xFF000FAA), Color(0xFF1A44EE)],
                            stops: const [0.0, 0.3, 0.65, 1.0],
                          ),
                        ),
                      ),
                      // Ana parlama
                      Positioned(
                        top: 9, left: 8,
                        child: Transform.rotate(
                          angle: -0.31,
                          child: Container(
                            width: 12, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      // İkinci parlama
                      Positioned(
                        top: 12, left: 18,
                        child: Transform.rotate(
                          angle: -0.31,
                          child: Container(
                            width: 6, height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      // Orta çizgi
                      Positioned(
                        top: 62, left: 0, right: 0,
                        child: Container(height: 1.5, color: Colors.black.withOpacity(0.45)),
                      ),
                      // Mavi için cam efekti
                      if (!isRed)
                        Positioned(
                          top: 63, left: 0, right: 0, bottom: 0,
                          child: Container(color: const Color(0xFF6496FF).withOpacity(0.1)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
