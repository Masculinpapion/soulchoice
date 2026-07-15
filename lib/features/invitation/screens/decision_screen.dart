import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class DecisionScreen extends StatefulWidget {
  final String invitationId;
  const DecisionScreen({super.key, required this.invitationId});

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen>
    with SingleTickerProviderStateMixin {
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
  // Kabul anında match.meeting_date'e kopyalanır — buluşma anketi + arşiv
  // mekaniğini besler (product-logic §7).
  DateTime? _eventDate;

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
        .select('title, event_date')
        .eq('id', widget.invitationId)
        .maybeSingle();
    if (mounted && data != null) {
      final rawEvent = data['event_date'] as String?;
      setState(() {
        _invitationTitle = data['title'] as String?;
        _eventDate = rawEvent != null ? DateTime.tryParse(rawEvent) : null;
      });
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

      // Mevcut match var mı kontrol et (idempotent)
      Map<String, dynamic>? matchRes;
      final existing = await client
          .from('matches')
          .select('id')
          .eq('invitation_id', widget.invitationId)
          .eq('user2_id', _applicantId!)
          .maybeSingle();
      if (existing != null) {
        matchRes = existing;
      } else {
        matchRes = await client
            .from('matches')
            .insert({
              'invitation_id': widget.invitationId,
              'user1_id': uid,
              'user2_id': _applicantId!,
              // Buluşma tarihi belirtilmişse anket + arşiv mekaniğini besle
              if (_eventDate != null)
                'meeting_date': _eventDate!.toIso8601String(),
            })
            .select('id')
            .single();
      }

      // .select() ile etkilenen satırı doğrula — RLS/policy sessizce 0 satır
      // güncellerse (eski kabul-akışı hatası) kabul başarısız sayılmalı.
      final updated = await client
          .from('applications')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _applicationId!)
          .select('id');
      if ((updated as List).isEmpty) {
        throw Exception('accept_not_persisted');
      }

      // Seçilen başvurana push bildirim (in-app kaydı DB trigger'ından gelir).
      final l10n = AppLocalizations.of(context)!;
      client.functions.invoke('send-notification', body: {
        'user_id': _applicantId,
        'title': l10n.notif_selected_push_title,
        'body': l10n.notif_selected_push_body,
        'data': {'type': 'selected', 'invitation_id': widget.invitationId},
      });

      if (mounted) context.go('/chat/${matchRes['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            backgroundColor: AuroraTheme.bgDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AuroraTheme.auroraRed.withOpacity(0.4)),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AuroraTheme.auroraRed,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.decision_error(e.toString()),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      await Supabase.instance.client
          .from('applications')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _applicationId!);
    } catch (_) {}
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _applicantName ?? AppLocalizations.of(context)!.decision_fallback_name;
    final title = _invitationTitle ?? '...';

    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    AnimatedBuilder(
                      animation: _pillGlow,
                      builder: (_, __) {
                        final t = _pillGlow.value;
                        final floatY = math.sin(t * math.pi * 2) * 10.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(0, floatY),
                              child: _GlossyPill(
                                isBlue: false,
                                glowIntensity: t,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Transform.translate(
                              offset: Offset(0, -floatY),
                              child: _GlossyPill(
                                isBlue: true,
                                glowIntensity: t,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Text(
                      AppLocalizations.of(context)!.decision_selected_title,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: AuroraTheme.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.decision_selected_body(name, title),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: AuroraTheme.textPrimary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AuroraTheme.auroraRed,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _timeExpired
                          ? AppLocalizations.of(context)!.decision_time_expired
                          : AppLocalizations.of(
                              context,
                            )!.decision_time_remaining,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: _timeExpired
                            ? AuroraTheme.auroraRed
                            : AuroraTheme.textMuted,
                        letterSpacing: 0.25,
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
        ),
      ),
    );
  }
}

class _GlossyPill extends StatelessWidget {
  final bool isBlue;
  final double glowIntensity;
  const _GlossyPill({required this.isBlue, required this.glowIntensity});

  @override
  Widget build(BuildContext context) {
    final glowColor = isBlue
        ? const Color(0xFF2D7FFF)
        : const Color(0xFFFF2D55);
    return Container(
      width: 54,
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.18 + glowIntensity * 0.42),
            blurRadius: 40,
            spreadRadius: 8,
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isBlue
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
            Positioned(
              top: 8,
              left: 7,
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
            Positioned(
              top: 14,
              left: 24,
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
            Positioned(
              top: 63,
              left: 0,
              right: 0,
              child: Container(height: 2, color: Colors.black.withOpacity(0.4)),
            ),
            Positioned(
              top: 65,
              left: 0,
              right: 0,
              bottom: 0,
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
            Positioned(
              bottom: 10,
              right: 8,
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
    );
  }
}
