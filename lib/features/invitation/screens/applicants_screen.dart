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
              Expanded(
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
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ApplicantCard(
                            app: applicants[i],
                            invitationId: invitationId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantCard extends StatefulWidget {
  final Map<String, dynamic> app;
  final String invitationId;

  const _ApplicantCard({required this.app, required this.invitationId});

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  late PageController _ctrl;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final applicant = app['applicant'] as Map<String, dynamic>?;
    final name = applicant?['name'] as String? ?? '—';
    final age = applicant?['age'] as int? ?? 0;
    final verified = applicant?['verified'] as bool? ?? false;
    final bio = applicant?['bio'] as String?;
    final applicationId = app['id'] as String;
    final applicantId = applicant?['id'] as String? ?? '';
    final status = app['status'] as String? ?? 'pending';
    final matchId = app['match_id'] as String?;
    final isAccepted = status == 'accepted';

    final rawPhotos = applicant?['photos'] as List<dynamic>? ?? [];
    final photos = List<Map<String, dynamic>>.from(rawPhotos)
      ..sort((a, b) {
        final aP = a['is_primary'] as bool? ?? false;
        final bP = b['is_primary'] as bool? ?? false;
        return aP ? -1 : (bP ? 1 : 0);
      });

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {
        if (isAccepted && matchId != null) {
          context.push('/chat/$matchId');
        } else {
          context.push(
            '/profile/$applicantId',
            extra: {
              'applicationId': applicationId,
              'invitationId': widget.invitationId,
              'applicantName': name,
            },
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.isNotEmpty)
                  PageView.builder(
                    controller: _ctrl,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: photos[i]['url'] as String? ?? '',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.glassBg,
                        child: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    color: AppColors.glassBg,
                    child: const Center(
                      child: Icon(Icons.person_outline, color: AppColors.textSecondary, size: 48),
                    ),
                  ),

                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 110,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      ),
                    ),
                  ),
                ),

                if (photos.length > 1)
                  Positioned(
                    top: 12, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(photos.length, (i) {
                        final active = i == _currentPhoto;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),

                Positioned(
                  bottom: 12, left: 14, right: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Manrope',
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (verified)
                        Container(
                          width: 20, height: 20,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)]),
                            boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(0.4), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      if (isAccepted)
                        Container(
                          width: 20, height: 20,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)]),
                          ),
                          child: const Icon(Icons.chat_bubble, size: 11, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: bio != null && bio.isNotEmpty
                      ? Text(bio, style: AppTextStyles.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : isAccepted
                          ? Text(AppLocalizations.of(context)!.chat_open, style: AppTextStyles.monoSmall.copyWith(color: const Color(0xFF2D7FFF)))
                          : const SizedBox.shrink(),
                ),
                Icon(
                  isAccepted ? Icons.chat_bubble_outline : Icons.chevron_right,
                  color: isAccepted ? const Color(0xFF2D7FFF) : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
