import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/profile_provider.dart';

class ProfileViewScreen extends ConsumerWidget {
  final String userId;
  const ProfileViewScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final photosAsync = ref.watch(userPhotosProvider(userId));
    final promptsAsync = ref.watch(userPromptsProvider(userId));
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUid == userId;

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: profileAsync.when(
          loading: () => Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(AppColors.gradientStart),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Text('$e',
                style: AppTextStyles.bodyMedium),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text('Profil bulunamadı',
                    style: AppTextStyles.bodyMedium),
              );
            }

            final name = user['name'] as String? ?? '—';
            final age = user['age'] as int? ?? 0;
            final verified = user['verified'] as bool? ?? false;
            final bio = user['bio'] as String?;
            final city = user['city'] as Map<String, dynamic>?;
            final cityName = city?['name'] as String? ?? '';
            final interests =
                (user['interests'] as List?)?.cast<String>() ?? [];
            final photos = photosAsync.asData?.value ?? [];

            return CustomScrollView(
              slivers: [
                // ── Hero photo ────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 540,
                  pinned: true,
                  backgroundColor: AppColors.bgBlack,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => context.pop(),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: isOwnProfile
                          ? _GlassIconButton(
                              icon: Icons.settings_outlined,
                              onTap: () => context.push('/settings'),
                            )
                          : _GlassIconButton(
                              icon: Icons.more_horiz,
                              onTap: () =>
                                  _showActionSheet(context, userId),
                            ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _PhotoCarousel(photos: photos),
                  ),
                ),

                // ── Floating glass panel ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgBlack,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag indicator
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 14),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // ── Name / age / location ──────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '$name, $age',
                                            style: AppTextStyles.displayMedium
                                                .copyWith(
                                                    fontSize: 30,
                                                    fontStyle:
                                                        FontStyle.normal),
                                          ),
                                          if (verified) ...[
                                            const SizedBox(width: 8),
                                            ShaderMask(
                                              shaderCallback: (b) =>
                                                  AppColors.primaryGradient
                                                      .createShader(b),
                                              child: const Icon(
                                                  Icons.verified,
                                                  color: Colors.white,
                                                  size: 22),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (cityName.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.location_on_outlined,
                                                size: 14,
                                                color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(cityName,
                                                style: AppTextStyles.bodyMedium),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Bio ────────────────────────────────────────
                          if (bio != null && bio.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 20, 24, 0),
                              child: GlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Text(bio,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.6)),
                              ),
                            ),
                          ],

                          // ── Interests ──────────────────────────────────
                          if (interests.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İLGİ ALANLARI',
                                    style: AppTextStyles.monoSmall.copyWith(
                                        letterSpacing: 2,
                                        color: AppColors.textTertiary),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests
                                        .map((i) =>
                                            _InterestChip(label: i))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ── Prompts ────────────────────────────────────
                          promptsAsync.maybeWhen(
                            data: (prompts) {
                              if (prompts.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 24, 24, 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SORULAR',
                                      style: AppTextStyles.monoSmall
                                          .copyWith(
                                              letterSpacing: 2,
                                              color: AppColors.textTertiary),
                                    ),
                                    const SizedBox(height: 12),
                                    ...prompts.map((p) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _PromptCard(
                                            question: _questionLabel(
                                                p['question_key']
                                                    as String),
                                            answer: p['answer']
                                                    as String? ??
                                                '',
                                          ),
                                        )),
                                  ],
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),

                          // ── CTA ────────────────────────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 28, 24, 48),
                            child: _GradientCTA(
                              label: 'Gelmek isterim',
                              onTap: () => context.pop(),
                            ),
                          ),
                        ],
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

  String _questionLabel(String key) {
    const labels = {
      'favorite_restaurant': 'Favori restoranım...',
      'last_book': 'Son okuduğum kitap...',
      'perfect_evening': 'Mükemmel bir akşam...',
      'travel_dream': 'Hayalimdeki seyahat...',
    };
    return labels[key] ?? key;
  }

  void _showActionSheet(BuildContext context, String targetUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ActionSheet(targetUserId: targetUserId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassBgStrong,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, size: 18, color: AppColors.textPrimary),
            ),
          ),
        ),
      );
}

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary, fontSize: 12)),
      );
}

class _PromptCard extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: AppTextStyles.monoSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            Text(answer, style: AppTextStyles.bodyLarge),
          ],
        ),
      );
}

class _GradientCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientStart.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.labelLarge
                    .copyWith(color: Colors.white)),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSheet extends StatelessWidget {
  final String targetUserId;
  const _ActionSheet({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: AppColors.error),
          title: Text('Şikayet et',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.error)),
          onTap: () async {
            Navigator.pop(context);
            final uid =
                Supabase.instance.client.auth.currentUser?.id;
            if (uid == null) return;
            await Supabase.instance.client.from('reports').insert({
              'reporter_id': uid,
              'reported_user_id': targetUserId,
              'reason': 'user_report',
              'status': 'pending',
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Şikayetiniz alındı, inceleniyor.')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.block, color: AppColors.textSecondary),
          title:
              Text('Engelle', style: AppTextStyles.bodyLarge),
          onTap: () async {
            Navigator.pop(context);
            final uid =
                Supabase.instance.client.auth.currentUser?.id;
            if (uid == null) return;
            await Supabase.instance.client.from('blocks').upsert({
              'blocker_id': uid,
              'blocked_id': targetUserId,
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kullanıcı engellendi.')),
              );
              context.pop();
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo Carousel
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        color: AppColors.bgCard,
        child: const Center(
          child: Icon(Icons.person_outline,
              size: 80, color: AppColors.textTertiary),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final url = widget.photos[i]['url'] as String;
            return Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.bgCard,
                child: const Icon(Icons.person_outline,
                    size: 60, color: AppColors.textTertiary),
              ),
            );
          },
        ),
        // Bottom gradient leading into the panel
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [Color(0xFF070B14), Colors.transparent],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        // Photo indicator dots — top center (bar style)
        if (widget.photos.length > 1)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: List.generate(widget.photos.length, (i) {
                    final isActive = i == _current;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i < widget.photos.length - 1 ? 4 : 0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? AppColors.primaryGradient
                                : null,
                            color: isActive
                                ? null
                                : AppColors.glassBorderBright,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
