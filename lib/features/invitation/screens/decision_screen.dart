import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class DecisionScreen extends StatefulWidget {
  final String invitationId;
  const DecisionScreen({super.key, required this.invitationId});

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> with SingleTickerProviderStateMixin {
  static const _totalSeconds = 3600;
  int _remainingSeconds = _totalSeconds;
  late Timer _timer;
  late AnimationController _pillController;
  late Animation<double> _pillGlow;
  bool _isLoading = false;
  bool get _timeExpired => _remainingSeconds == 0;

  String? _applicationId;
  String? _applicantId;
  String? _applicantName;
  String? _invitationTitle;

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _applicationId = extra?['applicationId'] as String?;
    _applicantId = extra?['applicantId'] as String?;
    _applicantName = extra?['applicantName'] as String?;
    _loadInvitationTitle();
  }

  Future<void> _loadInvitationTitle() async {
    final data = await Supabase.instance.client
        .from('invitations')
        .select('title')
        .eq('id', widget.invitationId)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() => _invitationTitle = data['title'] as String?);
    }
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
    if (_applicationId == null || _applicantId == null) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final uid = user.id;

      final matchRes = await client.from('matches').insert({
        'invitation_id': widget.invitationId,
        'user1_id': uid,
        'user2_id': _applicantId!,
      }).select('id').single();

      await client.from('applications').update({
        'status': 'accepted',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', _applicationId!);

      if (mounted) context.go('/chat/${matchRes['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.decision_error(e.toString())), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reject() async {
    if (_applicationId == null) {
      context.pop();
      return;
    }
    try {
      await Supabase.instance.client.from('applications').update({
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', _applicationId!);
    } catch (_) {}
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = _applicantName ?? AppLocalizations.of(context)!.decision_fallback_name;
    final title = _invitationTitle ?? '...';

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                AnimatedBuilder(
                  animation: _pillGlow,
                  builder: (_, __) => Container(
                    width: 72,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: AuroraTheme.redBlueGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AuroraTheme.auroraRed.withOpacity(_pillGlow.value * 0.6),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: AuroraTheme.auroraBlue.withOpacity(_pillGlow.value * 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(AppLocalizations.of(context)!.decision_selected_title, style: AppTextStyles.displayLarge),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.decision_selected_body(name, title),
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(_timeLabel, style: AppTextStyles.monoLarge.copyWith(color: AuroraTheme.auroraRed)),
                Text(
                  _timeExpired
                      ? AppLocalizations.of(context)!.decision_time_expired
                      : AppLocalizations.of(context)!.decision_time_remaining,
                  style: AppTextStyles.monoSmall.copyWith(
                    color: _timeExpired ? AppColors.error : null,
                  ),
                ),
                const Spacer(),
                ScButton(
                  label: AppLocalizations.of(context)!.decision_accept,
                  onPressed: _isLoading || _timeExpired ? null : _accept,
                  isLoading: _isLoading,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                ScButton(
                  label: AppLocalizations.of(context)!.decision_reject,
                  variant: ScButtonVariant.ghost,
                  onPressed: _isLoading || _timeExpired ? null : _reject,
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
