import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart' show ScButton;
import '../providers/discover_provider.dart';

// ── Deterministik aspect ratio (scroll'da zıplama olmasın) ──────────────────
double _cardAspect(String id) {
  final h = id.hashCode.abs() % 3;
  if (h == 0) return 0.7;
  if (h == 1) return 0.85;
  return 1.0;
}

// ── Ana ekran ────────────────────────────────────────────────────────────────
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AppBar ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Keşfet',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    color: Colors.white,
                  ),
                ),
              ),

              // ── İçerik ───────────────────────────────────────────────────
              Expanded(
                child: async.when(
                  loading: () => const _LoadingGrid(),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(discoverProvider),
                  ),
                  data: (invitations) {
                    if (invitations.isEmpty) {
                      return _EmptyState(
                        onCreateTap: () => context.push('/invitation/create'),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primaryRed,
                      backgroundColor: AppColors.bgCard,
                      onRefresh: () async =>
                          ref.invalidate(discoverProvider),
                      child: MasonryGridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: invitations.length,
                        itemBuilder: (ctx, i) {
                          final inv = invitations[i];
                          return _DiscoverCard(
                            invitation: inv,
                            aspect: _cardAspect(inv.id),
                            onTap: () =>
                                context.push('/invitation/${inv.id}'),
                          );
                        },
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

// ── Kart ─────────────────────────────────────────────────────────────────────
class _DiscoverCard extends StatelessWidget {
  final InvitationModel invitation;
  final double aspect;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.invitation,
    required this.aspect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invitation;
    final ownerName = inv.owner?.name ?? '';
    final ownerAge = inv.owner?.age ?? 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {}, // ileride: paylaş / favorile menüsü
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Fotoğraf ──────────────────────────────────────────────
              CachedNetworkImage(
                imageUrl: inv.ownerPhotoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.bgCard),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.bgCard,
                  child: const Icon(Icons.image_not_supported,
                      color: AppColors.textTertiary),
                ),
              ),

              // ── Alt gradient overlay ───────────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.7],
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Kategori rozeti (üst sol) ─────────────────────────────
              Positioned(
                top: 10,
                left: 10,
                child: _CategoryBadge(
                  emoji: inv.category.emoji,
                  label: inv.category.label,
                ),
              ),

              // ── Alt bilgi ─────────────────────────────────────────────
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inv.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (ownerName.isNotEmpty)
                      Text(
                        ownerAge > 0
                            ? '$ownerName, $ownerAge'
                            : ownerName,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      timeago.format(inv.createdAt, locale: 'tr'),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        color: Colors.white60,
                      ),
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

// ── Kategori rozeti ───────────────────────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  final String emoji;
  final String label;

  const _CategoryBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glassBgStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Text(
        '$emoji $label',
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Boş durum ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              'Henüz aktif davet yok',
              style: AppTextStyles.headingLarge.copyWith(
                fontFamily: 'Fraunces',
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'İlk davetini sen aç, burada görünsün',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ScButton(
              label: '+ Davet Aç',
              onPressed: onCreateTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yükleme iskeleti ──────────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    const aspects = [0.7, 0.85, 1.0, 0.7, 1.0, 0.85, 0.7, 0.85];
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 8,
      itemBuilder: (_, i) => AspectRatio(
        aspectRatio: aspects[i % aspects.length],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(color: AppColors.bgCard),
        ),
      ),
    );
  }
}

// ── Hata durumu ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bağlantı hatası',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Tekrar dene',
                style: TextStyle(color: AppColors.primaryRed)),
          ),
        ],
      ),
    );
  }
}
