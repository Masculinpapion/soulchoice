import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

class DecisionScreen extends StatefulWidget {
  final String invitationId;
  const DecisionScreen({super.key, required this.invitationId});

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen>
    with SingleTickerProviderStateMixin {
  static const _totalSeconds = 3600; // 1 hour
  int _remainingSeconds = _totalSeconds;
  late Timer _timer;
  late AnimationController _pillController;
  late Animation<double> _pillGlow;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pillGlow = Tween<double>(begin: 0.4, end: 1.0).animate(_pillController);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pillController.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _accept() async {
    // TODO: local_auth biometric
    setState(() => _isAccepting = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) context.go('/chat/match_1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                // Big red pill
                AnimatedBuilder(
                  animation: _pillGlow,
                  builder: (ctx, _) => Container(
                    width: 72,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.redGlow.withOpacity(_pillGlow.value),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.red.withOpacity(0.9),
                          AppColors.red,
                          AppColors.red.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text('Seçildiniz!', style: AppTextStyles.displayLarge),
                const SizedBox(height: 12),
                Text(
                  'Dmitri sizi davetine seçti.\nKabul etmek istiyor musunuz?',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  _timeLabel,
                  style: AppTextStyles.monoLarge.copyWith(color: AppColors.red),
                ),
                Text('kalan süre', style: AppTextStyles.monoSmall),
                const Spacer(),
                ScButton(
                  label: 'Evet, kabul ediyorum',
                  onPressed: _accept,
                  isLoading: _isAccepting,
                  icon: Icons.fingerprint,
                ),
                const SizedBox(height: 12),
                ScButton(
                  label: 'Hayır, reddet',
                  variant: ScButtonVariant.ghost,
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
