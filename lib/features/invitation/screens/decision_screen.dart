import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _DecisionScreenState extends State<DecisionScreen> with SingleTickerProviderStateMixin {
  static const _totalSeconds = 3600;
  int _remainingSeconds = _totalSeconds;
  late Timer _timer;
  late AnimationController _pillController;
  late Animation<double> _pillGlow;
  bool _isLoading = false;

  String? _applicationId;
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
    final extra = GoRouterState.of(context).extra as Map<String, String>?;
    _applicationId = extra?['applicationId'];
    _applicantName = extra?['applicantName'];
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
    if (_applicationId == null) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;

      final invRow = await client
          .from('invitations')
          .select('owner_id')
          .eq('id', widget.invitationId)
          .maybeSingle();

      final ownerId = invRow?['owner_id'] as String? ?? '';

      final matchRes = await client.from('matches').insert({
        'invitation_id': widget.invitationId,
        'user1_id': ownerId,
        'user2_id': uid,
      }).select('id').single();

      await client.from('applications').update({
        'status': 'accepted',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', _applicationId!);

      if (mounted) context.go('/chat/${matchRes['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
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
    final name = _applicantName ?? 'Kişi';
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
                        colors: [AppColors.red.withOpacity(0.9), AppColors.red, AppColors.red.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text('Seçildiniz!', style: AppTextStyles.displayLarge),
                const SizedBox(height: 12),
                Text(
                  '$name sizi "$title" davetine seçti.\nKabul etmek istiyor musunuz?',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(_timeLabel, style: AppTextStyles.monoLarge.copyWith(color: AppColors.red)),
                Text('kalan süre', style: AppTextStyles.monoSmall),
                const Spacer(),
                ScButton(
                  label: 'Evet, kabul ediyorum',
                  onPressed: _isLoading ? null : _accept,
                  isLoading: _isLoading,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                ScButton(
                  label: 'Hayır, reddet',
                  variant: ScButtonVariant.ghost,
                  onPressed: _isLoading ? null : _reject,
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
