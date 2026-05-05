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
          _Pill(isBlue: data.pillColor == AppColors.blue, delay: Duration.zero),
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

// ─── Gerçekçi 3D hap ─────────────────────────────────────────────────────────

class _Pill extends StatefulWidget {
  final bool isBlue;
  final Duration delay;
  const _Pill({this.isBlue = false, this.delay = Duration.zero});
  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final floatY = widget.isBlue
            ? -math.sin(t * 2 * math.pi) * 10.0
            : math.sin(t * 2 * math.pi) * 10.0;
        final glowOpacity = 0.18 + t * 0.14;
        final glowColor = widget.isBlue
            ? const Color(0xFF2D7FFF)
            : const Color(0xFFFF2D55);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Container(
            width: 54,
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(glowOpacity),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(3, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                children: [
                  // Ana gövde — derin 3D gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isBlue
                            ? const [
                                Color(0xFF5588DD),
                                Color(0xFF1133BB),
                                Color(0xFF001088),
                                Color(0xFF0A2299),
                                Color(0xFF1133BB),
                              ]
                            : const [
                                Color(0xFFDD4444),
                                Color(0xFFBB1111),
                                Color(0xFF880006),
                                Color(0xFF991100),
                                Color(0xFFBB1111),
                              ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                  // Kenar karartma (derinlik)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                  // Üst parlama (ana yansıma)
                  Positioned(
                    top: 8, left: 7,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        width: 14,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.55),
                              Colors.white.withOpacity(0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // İkincil ince parlama
                  Positioned(
                    top: 14, left: 24,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        width: 5,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  // Orta bant (kapsül birleşim çizgisi)
                  Positioned(
                    top: 63, left: 0, right: 0,
                    child: Container(
                      height: 2,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  // Alt yarı biraz daha koyu
                  Positioned(
                    top: 65, left: 0, right: 0, bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Alt küçük parlama
                  Positioned(
                    bottom: 10, right: 8,
                    child: Container(
                      width: 8,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
