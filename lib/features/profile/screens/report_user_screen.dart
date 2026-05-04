import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

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

  int? _selectedReason;
  final _descController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.report_error_no_reason),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _sending = true);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.report_success),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.report_error(e.toString())),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context)!.report_title,
            style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(AppLocalizations.of(context)!.report_why,
                style: AppTextStyles.labelLarge),
            const SizedBox(height: 12),
            ..._getReasons(context).asMap().entries.map((e) => GestureDetector(
                  onTap: () => setState(() => _selectedReason = e.key),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedReason == e.key
                                  ? AppColors.gradientStart
                                  : AppColors.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: _selectedReason == e.key
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.gradientStart,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(e.value, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.report_desc_label,
                style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            GlassCard(
              child: TextField(
                controller: _descController,
                style: AppTextStyles.bodyLarge,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.report_desc_hint,
                  hintStyle: AppTextStyles.bodyMedium,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterStyle: AppTextStyles.monoSmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ScButton(
              label: _sending ? AppLocalizations.of(context)!.report_btn_sending : AppLocalizations.of(context)!.report_btn_submit,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
