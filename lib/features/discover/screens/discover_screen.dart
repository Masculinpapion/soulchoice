import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart' show ScButton;
import '../providers/discover_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

// Deterministik aspect ratio — hash bazlı, iki seçenek
double _cardAspect(String id) =>
    id.hashCode.abs() % 2 == 0 ? 0.72 : 0.88;

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  InvitationCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: Text(
                    AppLocalizations.of(context)!.discover_title,
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      fontSize: MediaQuery.of(context).size.width < 360 ? 25.5 : 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              // Mono label
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  AppLocalizations.of(context)!.discover_all_invitations_label,
                  style: AuroraTheme.monoLabel,
                ),
              ),

              // Filtre chip'leri
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: AppLocalizations.of(context)!.discover_filter_all,
                      emoji: '✦',
                      selected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    ...InvitationCategory.values.map((cat) => _FilterChip(
                          label: cat.labelFor(AppLocalizations.of(context)!),
                          emoji: cat.emoji,
                          selected: _selectedCategory == cat,
                          onTap: () => setState(() =>
                              _selectedCategory =
                                  _selectedCategory == cat ? null : cat),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // İçerik
              Expanded(
                child: async.when(
                  loading: () => const _LoadingGrid(),
                  error: (e, _) =>
                      _ErrorState(message: AppLocalizations.of(context)!.discover_error, retryLabel: AppLocalizations.of(context)!.btn_try_again, onRetry: () => ref.invalidate(discoverProvider)),
                  data: (allInvitations) {
                    final invitations = _selectedCategory == null
                        ? allInvitations
                        : allInvitations
                            .where((inv) => inv.category == _selectedCategory)
                            .toList();
                    if (invitations.isEmpty) {
                      return _EmptyState(
                        title: AppLocalizations.of(context)!.discover_empty_title,
                        subtitle: AppLocalizations.of(context)!.discover_empty_subtitle,
                        btnLabel: AppLocalizations.of(context)!.discover_btn_create,
                        onCreateTap: () =>
                            context.push('/invitation/create'),
                      );
                    }
                    return RefreshIndicator(
                      color: AuroraTheme.auroraRed,
                      backgroundColor: AuroraTheme.glassStrong,
                      onRefresh: () async =>
                          ref.invalidate(discoverProvider),
                      child: MasonryGridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuroraTheme.radiusCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AuroraTheme.radiusCard),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fotoğraf
                photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: Colors.white.withOpacity(0.05)),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.05),
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.white24),
                        ),
                      )
                    : Container(color: Colors.white.withOpacity(0.05)),

                // Alt gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                          Colors.black.withOpacity(0.88),
                        ],
                      ),
                    ),
                  ),
                ),

                // Alt metin
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inv.cityName?.isNotEmpty == true
                              ? '${inv.cityName} · ${timeago.format(inv.createdAt, locale: 'ru')}'
                              : timeago.format(inv.createdAt, locale: 'ru'),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Üst sol — glass pill (avatar + isim)
                if (ownerName.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 44,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
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
                                radius: 11,
                                backgroundColor:
                                    Colors.white.withOpacity(0.1),
                                backgroundImage: photoUrl != null
                                    ? CachedNetworkImageProvider(photoUrl)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  ownerAge > 0
                                      ? '$ownerName, $ownerAge'
                                      : ownerName,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Üst sağ — kategori emoji
                Positioned(
                  top: 10,
                  right: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.40),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          inv.category.emoji,
                          style: TextStyle(
                            fontSize: inv.category == InvitationCategory.concert ? 17 : 13,
                            color: inv.category == InvitationCategory.concert ? AuroraTheme.auroraRed : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Boş durum ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String btnLabel;
  final VoidCallback onCreateTap;
  const _EmptyState({required this.title, required this.subtitle, required this.btnLabel, required this.onCreateTap});

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
              title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: 22,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ScButton(label: btnLabel, onPressed: onCreateTap),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    const aspects = [0.72, 0.88, 0.72, 0.88, 0.72, 0.88, 0.72, 0.88];
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      padding: const EdgeInsets.all(14),
      itemCount: 8,
      itemBuilder: (_, i) => AspectRatio(
        aspectRatio: aspects[i % aspects.length],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AuroraTheme.radiusCard),
          child: Container(color: Colors.white.withOpacity(0.06)),
        ),
      ),
    );
  }
}

// ── Hata durumu ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.retryLabel, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
                fontFamily: 'Manrope',
                color: AuroraTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(retryLabel,
                style: const TextStyle(color: AuroraTheme.auroraRed)),
          ),
        ],
      ),
    );
  }
}

// ── Filtre Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                    )
                  : null,
              color: selected ? null : AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : AuroraTheme.glassBorder,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AuroraTheme.auroraRed.withOpacity(0.30),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: emoji == '♫' ? 15 : 11,
                    color: emoji == '♫' ? (selected ? Colors.white : AuroraTheme.auroraRed) : null,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AuroraTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
