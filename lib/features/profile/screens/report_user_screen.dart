import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../shared/widgets/sc_scaffold.dart';

class ReportUserScreen extends StatefulWidget {
  final String userId;
  const ReportUserScreen({super.key, required this.userId});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  static List<String> _getReasons(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      l.report_reason_inappropriate,
      l.report_reason_harassment,
      l.report_reason_spam,
      l.report_reason_illegal,
      l.report_reason_other,
    ];
  }

  static const int _otherReasonIndex = 4;

  int? _selectedReason;
  final _descController = TextEditingController();
  bool _sending = false;
  bool _descError = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _showAuroraSnack(
    String message, {
    required Color accentColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withOpacity(0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
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
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_selectedReason == null) {
      _showAuroraSnack(
        l.report_error_no_reason,
        accentColor: AuroraTheme.auroraGold,
        icon: Icons.error_outline,
      );
      return;
    }
    final isOther = _selectedReason == _otherReasonIndex;
    final descEmpty = _descController.text.trim().isEmpty;
    if (isOther && descEmpty) {
      setState(() => _descError = true);
      _showAuroraSnack(
        l.report_error_desc_required,
        accentColor: AuroraTheme.auroraGold,
        icon: Icons.error_outline,
      );
      return;
    }
    setState(() {
      _descError = false;
      _sending = true;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': uid,
        'reported_user_id': widget.userId,
        'reason': _getReasons(context)[_selectedReason!],
        'description': _descController.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        _showAuroraSnack(
          l.report_success,
          accentColor: AuroraTheme.auroraBlue,
          icon: Icons.check_circle_outline,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showAuroraSnack(
          AppLocalizations.of(context)!.report_error(e.toString()),
          accentColor: AuroraTheme.auroraRed,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOtherSelected = _selectedReason == _otherReasonIndex;
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    _GlassPill(
                      onTap: () => context.pop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: AuroraTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      l10n.report_title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AuroraTheme.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      l10n.report_why,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AuroraTheme.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._getReasons(context).asMap().entries.map((e) {
                      final isSelected = _selectedReason == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedReason = e.key),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AuroraTheme.radiusInfoCard,
                              ),
                              boxShadow: isSelected
                                  ? AuroraTheme.redGlow
                                  : null,
                            ),
                            child: GlassCard(
                              backgroundColor: isSelected
                                  ? AuroraTheme.auroraRed.withOpacity(0.10)
                                  : null,
                              borderColor: isSelected
                                  ? AuroraTheme.auroraRed
                                  : null,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AuroraTheme.auroraRed
                                            : AuroraTheme.glassBorder,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AuroraTheme.auroraRed,
                                              ),
                                              child: SizedBox(
                                                width: 10,
                                                height: 10,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        color: AuroraTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      isOtherSelected
                          ? l10n.report_desc_label_required
                          : l10n.report_desc_label,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _descError
                            ? AuroraTheme.auroraGold
                            : AuroraTheme.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GlassCard(
                      borderColor: _descError ? AuroraTheme.auroraGold : null,
                      child: TextField(
                        controller: _descController,
                        onChanged: (_) {
                          if (_descError) setState(() => _descError = false);
                        },
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          color: AuroraTheme.textPrimary,
                        ),
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: l10n.report_desc_hint,
                          hintStyle: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: AuroraTheme.textMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterStyle: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: AuroraTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ReportSubmitButton(
                      label: _sending
                          ? l10n.report_btn_sending
                          : l10n.report_btn_submit,
                      isLoading: _sending,
                      onTap: _sending ? null : _submit,
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

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            shape: BoxShape.circle,
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _ReportSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  const _ReportSubmitButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null && !isLoading;
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AuroraTheme.auroraRed.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
        ),
      ),
    );
  }
}
