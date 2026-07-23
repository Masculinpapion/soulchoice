import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/applications_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/services/photo_focus.dart';

class ApplicantsScreen extends ConsumerWidget {
  final String invitationId;
  const ApplicantsScreen({super.key, required this.invitationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
    final async = ref.watch(applicantsProvider(invitationId));

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
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
                      child: Text(
                        AppLocalizations.of(context)!.applicants_title,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AuroraTheme.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    async.maybeWhen(
                      data: (list) => Text(
                        AppLocalizations.of(context)!.applicants_count(list.length),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AuroraTheme.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AuroraTheme.auroraRed)),
                  error: (e, _) => Center(child: Text(AppLocalizations.of(context)!.error_generic, style: TextStyle(color: AuroraTheme.textSecondary))),
                  data: (applicants) {
                    if (applicants.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, color: AuroraTheme.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context)!.applicants_empty,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: AuroraTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AuroraTheme.auroraRed,
                      backgroundColor: AuroraTheme.glassBg,
                      onRefresh: () => ref.refresh(applicantsProvider(invitationId).future),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: applicants.length,
                        itemBuilder: (_, i) => _ApplicantTile(
                          app: applicants[i],
                          invitationId: invitationId,
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

class _ApplicantTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final String invitationId;

  const _ApplicantTile({required this.app, required this.invitationId});

  @override
  Widget build(BuildContext context) {
    final applicant = app['applicant'] as Map<String, dynamic>?;
    final name = applicant?['name'] as String? ?? '—';
    final age = applicant?['age'] as int? ?? 0;
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
    final primaryUrl = photos.isNotEmpty ? (photos.first['url'] as String? ?? '') : '';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isAccepted && matchId != null) {
            context.push(
              '/chat/$matchId',
              extra: {
                'name': name,
                'age': age,
                'photoUrl': primaryUrl.isNotEmpty ? primaryUrl : null,
              },
            );
          } else {
            context.push(
              '/profile/$applicantId',
              extra: {
                'applicationId': applicationId,
                'invitationId': invitationId,
                'applicantName': name,
              },
            );
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (primaryUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: primaryUrl,
                fit: BoxFit.cover,
                alignment: PhotoFocus.of(primaryUrl),
                errorWidget: (_, __, ___) => Container(
                  color: AuroraTheme.glassBg,
                  child: Icon(Icons.person_outline, color: AuroraTheme.textSecondary, size: 36),
                ),
              )
            else
              Container(
                color: AuroraTheme.glassBg,
                child: Center(
                  child: Icon(Icons.person_outline, color: AuroraTheme.textSecondary, size: 36),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 8, left: 10, right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$name, $age',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (isAccepted)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2D7FFF).withOpacity(0.6), width: 1),
                  ),
                  child: const Icon(Icons.chat_bubble, size: 12, color: Color(0xFF2D7FFF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
