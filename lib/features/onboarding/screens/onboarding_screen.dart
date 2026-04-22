import 'package:flutter/material.dart';
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

  static const _pages = [
    _OnboardingPage(
      pillColor: AppColors.red,
      pillGlow: AppColors.redGlow,
      title: 'Davetini aç,\nbir geceyi paylaş',
      subtitle: 'Yemek, konser, seyahat — 24 saatlik davetler aç ve birlikte git.',
    ),
    _OnboardingPage(
      pillColor: AppColors.blue,
      pillGlow: AppColors.blueGlow,
      title: 'Sen seçiyorsun,\nsen karar veriyorsun',
      subtitle: 'Başvuranların profillerini gör, kimi götüreceğine kendin karar ver.',
    ),
    _OnboardingPage(
      pillColor: AppColors.gold,
      pillGlow: AppColors.gold,
      title: 'Güvenli buluşma,\ngerçek deneyim',
      subtitle: 'Doğrulanmış profiller, biyometrik onay, birlikte gidilen gerçek anlar.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == i ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? AppColors.red : AppColors.glassBorder,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_currentPage < _pages.length - 1)
                      ScButton(
                        label: 'Devam',
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      )
                    else
                      ScButton(
                        label: 'Başla',
                        onPressed: () => context.go('/auth/phone'),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/auth/phone'),
                      child: Text('Atla', style: AppTextStyles.bodyMedium),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Color pillColor;
  final Color pillGlow;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.pillColor,
    required this.pillGlow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 110,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: pillGlow.withOpacity(0.5), blurRadius: 32, spreadRadius: 8),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [pillColor.withOpacity(0.9), pillColor, pillColor.withOpacity(0.7)],
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(title, style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
