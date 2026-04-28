import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/invitation_provider.dart';

class InvitationDetailScreen extends ConsumerWidget {
  final String invitationId;
  const InvitationDetailScreen({super.key, required this.invitationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(invitationDetailProvider(invitationId));
    final myAppAsync = ref.watch(myApplicationProvider(invitationId));
    final countAsync = ref.watch(applicationCountProvider(invitationId));
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: invAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.red)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (inv) {
            if (inv == null) {
              return const Center(child: Text('Davet bulunamadı', style: TextStyle(color: AppColors.textSecondary)));
            }

            final owner = inv['owner'] as Map<String, dynamic>?;
            final ownerPhotos = (owner?['photos'] as List<dynamic>?) ?? [];
            final sortedOwnerPhotos = ownerPhotos
                .cast<Map<String, dynamic>>()
                .where((p) => p['is_selfie'] == false)
                .toList()
              ..sort((a, b) => (a['order_index'] as int? ?? 99).compareTo(b['order_index'] as int? ?? 99));
            final ownerPhotoUrl = sortedOwnerPhotos.firstOrNull?['url'] as String?;
            final isOwner = uid == inv['owner_id'];
            final category = InvitationCategory.values.firstWhere(
              (c) => c.name == inv['category'],
              orElse: () => InvitationCategory.food,
            );
            final expiresAt = DateTime.parse(inv['expires_at'] as String);
            final remaining = expiresAt.difference(DateTime.now());
            final hoursLeft = remaining.inHours;

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 300,
                      pinned: true,
                      backgroundColor: AppColors.bgBlack,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: () => context.pop(),
                      ),
                      actions: [
                        if (isOwner)
                          IconButton(
                            icon: const Icon(Icons.people_outline),
                            onPressed: () => context.push('/invitation/$invitationId/applicants'),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ownerPhotoUrl != null)
                              CachedNetworkImage(
                                imageUrl: ownerPhotoUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.red.withOpacity(0.3), AppColors.blue.withOpacity(0.2)],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.red.withOpacity(0.3), AppColors.blue.withOpacity(0.2)],
                                  ),
                                ),
                              ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Color(0xDD0A0A0B)],
                                  stops: [0.4, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Text(
                                (inv['title'] as String).toUpperCase(),
                                style: AppTextStyles.feedCardTitle.copyWith(fontSize: 26),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Row(
                            children: [
                              _InfoChip(icon: Icons.category_outlined, label: '${category.emoji} ${category.label}'),
                              const SizedBox(width: 8),
                              _InfoChip(icon: Icons.timer_outlined, label: '${hoursLeft}s kaldı'),
                              const SizedBox(width: 8),
                              countAsync.maybeWhen(
                                data: (n) => _InfoChip(icon: Icons.people_outline, label: '$n başvuru'),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (inv['description'] != null) ...[
                            const SizedBox(height: 20),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Etkinlik', style: AppTextStyles.monoSmall),
                                  const SizedBox(height: 6),
                                  Text(inv['description'] as String, style: AppTextStyles.bodyLarge),
                                ],
                              ),
                            ),
                          ],
                          if (inv['venue_name'] != null || inv['event_date'] != null) ...[
                            const SizedBox(height: 12),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Yer & Zaman', style: AppTextStyles.monoSmall),
                                  const SizedBox(height: 6),
                                  if (inv['venue_name'] != null)
                                    Row(children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(inv['venue_name'] as String, style: AppTextStyles.bodyMedium),
                                    ]),
                                  if (inv['event_date'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(_formatDate(DateTime.parse(inv['event_date'] as String)), style: AppTextStyles.bodyMedium),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (owner != null) ...[
                            const SizedBox(height: 20),
                            Text('Davet sahibi', style: AppTextStyles.labelLarge),
                            const SizedBox(height: 10),
                            GlassCard(
                              onTap: () => context.push('/profile/${owner['id']}'),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: ownerPhotoUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: ownerPhotoUrl,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              errorWidget: (_, __, ___) => Container(
                                                color: AppColors.glassBg,
                                                child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                                              ),
                                            )
                                          : Container(
                                              color: AppColors.glassBg,
                                              child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('${owner['name']}, ${owner['age']}', style: AppTextStyles.titleMedium),
                                        if (owner['verified'] == true) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, color: AppColors.gold, size: 16),
                                        ],
                                      ]),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.bgBlack, Colors.transparent],
                      ),
                    ),
                    child: isOwner
                        ? ScButton(
                            label: 'Başvuranları gör',
                            icon: Icons.people_outline,
                            onPressed: () => context.push('/invitation/$invitationId/applicants'),
                          )
                        : myAppAsync.when(
                            loading: () => const ScButton(label: 'Yükleniyor...', onPressed: null),
                            error: (_, __) => const ScButton(label: 'Hata', onPressed: null),
                            data: (myApp) => _ApplyButton(
                              invitationId: invitationId,
                              existingApp: myApp,
                              onApplied: () => ref.invalidate(myApplicationProvider(invitationId)),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Bugün $timeStr';
    if (diff == 1) return 'Yarın $timeStr';
    return '${dt.day}/${dt.month} $timeStr';
  }
}

class _ApplyButton extends ConsumerStatefulWidget {
  final String invitationId;
  final Map<String, dynamic>? existingApp;
  final VoidCallback onApplied;

  const _ApplyButton({required this.invitationId, this.existingApp, required this.onApplied});

  @override
  ConsumerState<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends ConsumerState<_ApplyButton> {
  bool _loading = false;

  Future<void> _apply() async {
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('applications').insert({
        'invitation_id': widget.invitationId,
        'applicant_id': uid,
        'status': 'pending',
      });
      widget.onApplied();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başvurunuz gönderildi! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.existingApp;
    if (app == null) {
      return ScButton(label: 'Gelmek isterim', onPressed: _loading ? null : _apply, isLoading: _loading);
    }
    final status = app['status'] as String;
    if (status == 'selected') {
      return ScButton(
        label: 'Seçildiniz — Kararınızı verin',
        icon: Icons.favorite_outline,
        onPressed: () => context.push('/invitation/${widget.invitationId}/decision',
            extra: {'applicationId': app['id']}),
      );
    }
    if (status == 'accepted') {
      return ScButton(label: '✓ Kabul edildi', onPressed: null, variant: ScButtonVariant.secondary);
    }
    return ScButton(label: 'Başvurdunuz', onPressed: null, variant: ScButtonVariant.secondary);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.monoSmall),
          ],
        ),
      );
}
