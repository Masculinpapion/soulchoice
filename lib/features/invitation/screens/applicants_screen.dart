import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/applications_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class ApplicantsScreen extends ConsumerWidget {
  final String invitationId;
  const ApplicantsScreen({super.key, required this.invitationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(applicantsProvider(invitationId));

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context)!.applicants_title, style: AppTextStyles.titleMedium),
        actions: [
          async.maybeWhen(
            data: (list) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(AppLocalizations.of(context)!.applicants_count(list.length), style: AppTextStyles.mono)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.red)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (applicants) {
            if (applicants.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context)!.applicants_empty, style: AppTextStyles.bodyMedium),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.glassBg,
              onRefresh: () => ref.refresh(applicantsProvider(invitationId).future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: applicants.length,
                itemBuilder: (_, i) {
                  final app = applicants[i];
                  final applicant = app['applicant'] as Map<String, dynamic>?;
                  final name = applicant?['name'] as String? ?? '—';
                  final age = applicant?['age'] as int? ?? 0;
                  final verified = applicant?['verified'] as bool? ?? false;
                  final bio = applicant?['bio'] as String?;
                  final applicationId = app['id'] as String;
                  final applicantId = applicant?['id'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () => context.push('/profile/$applicantId'),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.glassBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('$name, $age', style: AppTextStyles.titleMedium),
                                  if (verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: AppColors.gold, size: 16),
                                  ],
                                ]),
                                if (bio != null)
                                  Text(bio, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SelectButton(
                            invitationId: invitationId,
                            applicationId: applicationId,
                            applicantId: applicantId,
                            applicantName: name,
                            onSelected: () => ref.invalidate(applicantsProvider(invitationId)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}

class _SelectButton extends StatefulWidget {
  final String invitationId;
  final String applicationId;
  final String applicantId;
  final String applicantName;
  final VoidCallback onSelected;

  const _SelectButton({
    required this.invitationId,
    required this.applicationId,
    required this.applicantId,
    required this.applicantName,
    required this.onSelected,
  });

  @override
  State<_SelectButton> createState() => _SelectButtonState();
}

class _SelectButtonState extends State<_SelectButton> {
  bool _loading = false;

  Future<void> _select() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.rpc('match_and_select', params: {
        'p_application_id': widget.applicationId,
        'p_invitation_id': widget.invitationId,
      });

      widget.onSelected();

      if (mounted) {
        context.push(
          '/invitation/${widget.invitationId}/decision',
          extra: {
            'applicationId': widget.applicationId,
            'applicantId': widget.applicantId,
            'applicantName': widget.applicantName,
          },
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        final msg = e.message.contains('invitation_not_active')
            ? l.applicants_error_already_matched
            : e.message.contains('not_authorized')
                ? l.applicants_error_not_authorized
                : l.applicants_error_generic(e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.applicants_error_generic(e.toString())), backgroundColor: AppColors.error),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 38,
      child: ElevatedButton(
        onPressed: _loading ? null : _select,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(AppLocalizations.of(context)!.applicants_select_btn, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)),
      ),
    );
  }
}
