import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

const _kPermissionsRequestedKey = 'permissions_requested';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final List<bool?> _results = [null, null, null, null];

  @override
  void initState() {
    super.initState();
    _checkAlreadyRequested();
  }

  Future<void> _checkAlreadyRequested() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPermissionsRequestedKey) == true) {
      if (mounted) context.go('/feed');
    }
  }

  static List<_PermissionStep> _getSteps(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      _PermissionStep(
        emoji: '🔔',
        title: l.perm_notification_title,
        description: l.perm_notification_desc,
      ),
      _PermissionStep(
        emoji: '📍',
        title: l.perm_location_title,
        description: l.perm_location_desc,
      ),
      _PermissionStep(
        emoji: '📷',
        title: l.perm_photos_title,
        description: l.perm_photos_desc,
      ),
      _PermissionStep(
        emoji: '🤳',
        title: l.perm_camera_title,
        description: l.perm_camera_desc,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<PermissionStatus> _requestPermission(int step) async {
    switch (step) {
      case 0:
        return Permission.notification.request();
      case 1:
        return Permission.locationWhenInUse.request();
      case 2:
        final status = await Permission.photos.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          return Permission.storage.request();
        }
        return status;
      case 3:
        return Permission.camera.request();
      default:
        return PermissionStatus.denied;
    }
  }

  Future<void> _handleGrant() async {
    if (_results[_currentStep] == true) {
      _advance();
      return;
    }
    final status = await _requestPermission(_currentStep);
    final granted = status.isGranted || status.isLimited;
    setState(() => _results[_currentStep] = granted);
    if (granted) {
      await Future.delayed(const Duration(milliseconds: 500));
      _advance();
    }
  }

  void _advance() {
    if (_currentStep < _getSteps(context).length - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPermissionsRequestedKey, true);
    if (mounted) context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final result = _results[_currentStep];
    final steps = _getSteps(context);
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _ProgressDots(total: steps.length, current: _currentStep),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (_, i) => _StepPage(
                    step: steps[i],
                    result: _results[i],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: result == false
                    ? _DeniedWidget(
                        onSettings: openAppSettings,
                        onContinue: _advance,
                      )
                    : Column(
                        children: [
                          ScButton(
                            label: result == true ? AppLocalizations.of(context)!.btn_continue : AppLocalizations.of(context)!.perm_grant,
                            onPressed: _handleGrant,
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _advance,
                            child: Text(
                              AppLocalizations.of(context)!.perm_not_now,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textTertiary,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textTertiary,
                              ),
                            ),
                          ),
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

class _PermissionStep {
  final String emoji;
  final String title;
  final String description;
  const _PermissionStep({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;
  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              gradient: isActive ? AppColors.primaryGradient : null,
              color: isActive ? null : AppColors.glassBgStrong,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      );
}

class _StepPage extends StatelessWidget {
  final _PermissionStep step;
  final bool? result;
  const _StepPage({required this.step, required this.result});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EmojiIllustration(emoji: step.emoji, granted: result),
            const SizedBox(height: 40),
            Text(step.title, style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(step.description, style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _EmojiIllustration extends StatelessWidget {
  final String emoji;
  final bool? granted;
  const _EmojiIllustration({required this.emoji, required this.granted});

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.gradientStart.withOpacity(0.15),
                AppColors.gradientEnd.withOpacity(0.05),
                Colors.transparent,
              ]),
            ),
          ),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassBgMedium,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 52))),
              ),
            ),
          ),
          if (granted == true)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.success),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
            ),
          if (granted == false)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withOpacity(0.85)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
        ],
      );
}

class _DeniedWidget extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onContinue;
  const _DeniedWidget({required this.onSettings, required this.onContinue});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.perm_denied_hint,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ScButton(label: AppLocalizations.of(context)!.perm_go_to_settings, onPressed: onSettings),
          const SizedBox(height: 12),
          ScButton(
              label: AppLocalizations.of(context)!.btn_continue,
              variant: ScButtonVariant.ghost,
              onPressed: onContinue),
        ],
      );
}
