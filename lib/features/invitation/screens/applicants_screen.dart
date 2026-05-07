import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!.applicants_title, style: AppTextStyles.titleMedium),
                    ),
                    async.maybeWhen(
                      data: (list) => Text(AppLocalizations.of(context)!.applicants_count(list.length), style: AppTextStyles.mono),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(child: async.when(
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
                  final photos = applicant?['photos'] as List<dynamic>? ?? [];
                  final primaryPhoto = photos.firstWhere(
                    (p) => p['is_primary'] == true,
                    orElse: () => photos.isNotEmpty ? photos.first : null,
                  );
                  final photoUrl = primaryPhoto?['url'] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: () => context.push(
                        '/profile/$applicantId',
                        extra: {
                          'applicationId': applicationId,
                          'invitationId': invitationId,
                          'applicantName': name,
                        },
                      ),
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
                            child: ClipOval(
                              child: photoUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(Icons.person_outline, color: AppColors.textSecondary),
                                    )
                                  : const Icon(Icons.person_outline, color: AppColors.textSecondary),
                            ),
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
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)],
                                        ),
                                        boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.3), blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                                    ),
                                  ],
                                ]),
                                if (bio != null)
                                  Text(bio, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          )),
        ],
      ),
    ),
  ),
);
  }
}

