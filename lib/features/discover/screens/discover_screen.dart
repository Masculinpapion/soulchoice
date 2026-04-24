import 'dart:ui';
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

// ── Deterministik aspect ratio (her zaman dikey portre) ─────────────────────
double _cardAspect(String id) {
  return id.hashCode.abs() % 2 == 0 ? 0.75 : 0.9;
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
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        padding: const EdgeInsets.all(16),
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
    final photoUrl = inv.ownerPhotoUrl;

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Fotoğraf ──────────────────────────────────────────────────
              photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.bgCard),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.bgCard,
                        child: const Icon(Icons.image_not_supported,
                            color: AppColors.textTertiary),
                      ),
                    )
                  : Container(color: AppColors.bgCard),

              // ── Alt gradient overlay ───────────────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.50),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Alt metin alanı ───────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inv.title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        timeago.format(inv.createdAt, locale: 'tr'),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          color: Colors.white60,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Üst sol — glass pill (avatar + isim/yaş) ─────────────────
              if (ownerName.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.40),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.bgCard,
                              backgroundImage: photoUrl != null
                                  ? CachedNetworkImageProvider(photoUrl)
                                  : null,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              ownerAge > 0
                                  ? '$ownerName, $ownerAge'
                                  : ownerName,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Üst sağ — kategori emoji (glass circle) ──────────────────
              Positioned(
                top: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        inv.category.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    const aspects = [0.75, 0.9, 0.75, 0.9, 0.75, 0.9, 0.75, 0.9];
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, i) => AspectRatio(
        aspectRatio: aspects[i % aspects.length],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
