import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
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
                valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Text('$e', style: AppTextStyles.bodyMedium),
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
            final selfieStatus = user['selfie_status'] as String? ?? 'none';
            final verified = selfieStatus == 'approved' ||
                (user['verified'] as bool? ?? false);
            final bio = user['bio'] as String?;
            final job = user['job'] as String?;
            final education = user['education'] as String?;
            final city = user['city'] as Map<String, dynamic>?;
            final cityName = city?['name'] as String? ?? '';
            final interests =
                (user['interests'] as List?)?.cast<String>() ?? [];
            final photos = photosAsync.asData?.value ?? [];

            return CustomScrollView(
              slivers: [
                // ── Hero photo (edge-to-edge, status bar overlap) ──────────
                SliverAppBar(
                  expandedHeight: 540,
                  pinned: true,
                  backgroundColor: AppColors.bgBlack,
                  systemOverlayStyle: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => context.pop(),
                    ),
                  ),
                  actions: [
                    if (!isOwnProfile && currentUid != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FavoriteButton(targetUserId: userId),
                      ),
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

                          // ── Name / age / verified ──────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Name + age + verified badge
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '$name, $age',
                                              style: AppTextStyles
                                                  .displayMedium
                                                  .copyWith(
                                                fontSize: 30,
                                                fontStyle: FontStyle.normal,
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
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
                                      const SizedBox(height: 8),
                                      // Location + job + education
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 4,
                                        children: [
                                          if (cityName.isNotEmpty)
                                            _MetaItem(
                                              icon: Icons
                                                  .location_on_outlined,
                                              text: cityName,
                                            ),
                                          if (job != null && job.isNotEmpty)
                                            _MetaItem(
                                              icon: Icons.work_outline,
                                              text: job,
                                            ),
                                          if (education != null &&
                                              education.isNotEmpty)
                                            _MetaItem(
                                              icon:
                                                  Icons.school_outlined,
                                              text: education,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Bio (plain text, no borders) ───────────────
                          if (bio != null && bio.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 20, 24, 0),
                              child: Text(
                                bio,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],

                          // ── Photo gallery strip ─────────────────────────
                          if (photos.length > 1) ...[
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 24),
                              child: Text(
                                'FOTOĞRAFLAR',
                                style: AppTextStyles.monoSmall.copyWith(
                                  letterSpacing: 2,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                itemCount: photos.length,
                                itemBuilder: (_, i) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _openPhotoViewer(
                                              context, photos, i),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: SizedBox(
                                          width: 80,
                                          height: 100,
                                          child: CachedNetworkImage(
                                            imageUrl: photos[i]['url']
                                                as String,
                                            fit: BoxFit.cover,
                                            alignment:
                                                Alignment.topCenter,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              color: AppColors.glassBg,
                                              child: const Icon(
                                                  Icons.person_outline,
                                                  color: AppColors
                                                      .textTertiary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // ── Interests ──────────────────────────────────
                          if (interests.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  24, 24, 24, 0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İLGİ ALANLARI',
                                    style: AppTextStyles.monoSmall
                                        .copyWith(
                                            letterSpacing: 2,
                                            color:
                                                AppColors.textTertiary),
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

                          // ── Prompts (no borders, Fraunces answers) ─────
                          promptsAsync.maybeWhen(
                            data: (prompts) {
                              if (prompts.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 28, 24, 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: prompts
                                      .map((p) => Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    bottom: 24),
                                            child: _PromptItem(
                                              question: _questionLabel(
                                                  p['question_key']
                                                      as String),
                                              answer: p['answer']
                                                      as String? ??
                                                  '',
                                            ),
                                          ))
                                      .toList(),
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),

                          // ── CTA (context-aware) ────────────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                24, 28, 24,
                                MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16),
                            child: isOwnProfile
                                ? _OutlineCTA(
                                    label: 'Profili Düzenle',
                                    onTap: () =>
                                        context.push('/profile/setup'),
                                  )
                                : _GradientCTA(
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

  void _openPhotoViewer(
      BuildContext context, List<Map<String, dynamic>> photos, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, __, ___) =>
            _PhotoViewerPage(photos: photos, initialIndex: index),
      ),
    );
  }

  void _showActionSheet(BuildContext context, String targetUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ActionSheet(targetUserId: targetUserId, targetName: null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta info item (city / job / education)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.bodyMedium),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Prompt item (no borders)
// ─────────────────────────────────────────────────────────────────────────────

class _PromptItem extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 19,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Icon Button
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

// ─────────────────────────────────────────────────────────────────────────────
// Favorite Button (glass circle, toggle with haptic + scale animation)
// ─────────────────────────────────────────────────────────────────────────────

class _FavoriteButton extends StatefulWidget {
  final String targetUserId;
  const _FavoriteButton({required this.targetUserId});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool? _isFavorite;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scaleAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _scaleCtrl.value = 1.0;
    _loadState();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final result = await Supabase.instance.client
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('favorited_user_id', widget.targetUserId)
        .maybeSingle();
    if (mounted) setState(() => _isFavorite = result != null);
  }

  Future<void> _toggle() async {
    if (_isFavorite == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    HapticFeedback.lightImpact();
    _scaleCtrl.reverse().then((_) => _scaleCtrl.forward());

    final next = !_isFavorite!;
    setState(() => _isFavorite = next);

    if (next) {
      await Supabase.instance.client.from('favorites').insert({
        'user_id': uid,
        'favorited_user_id': widget.targetUserId,
      });
    } else {
      await Supabase.instance.client
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('favorited_user_id', widget.targetUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFavorite == null) {
      return const SizedBox(width: 40, height: 40);
    }
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _toggle,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFavorite!
                    ? AppColors.red.withOpacity(0.18)
                    : AppColors.glassBgStrong,
                border: Border.all(
                  color: _isFavorite!
                      ? AppColors.red.withOpacity(0.5)
                      : AppColors.glassBorder,
                ),
              ),
              child: Icon(
                _isFavorite! ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite! ? AppColors.red : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interest Chip
// ─────────────────────────────────────────────────────────────────────────────

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

// ─────────────────────────────────────────────────────────────────────────────
// CTAs
// ─────────────────────────────────────────────────────────────────────────────

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
                style:
                    AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ),
      );
}

class _OutlineCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorderBright, width: 1.5),
            color: AppColors.glassBg,
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen Photo Viewer
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const _PhotoViewerPage(
      {required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          itemBuilder: (_, i) {
            final url = widget.photos[i]['url'] as String;
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 60),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSheet extends StatelessWidget {
  final String targetUserId;
  final String? targetName;
  const _ActionSheet({required this.targetUserId, this.targetName});

  Future<void> _block(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Kullanıcıyı engelle',
            style: AppTextStyles.titleMedium),
        content: Text(
          'Bu kullanıcıyı engellemek istediğine emin misin? Engelli kullanıcı seni göremez, mesaj atamaz.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Engelle',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('blocks').upsert({
      'blocker_id': uid,
      'blocked_id': targetUserId,
    });
    if (ctx.mounted) {
      ctx.pop(); // close bottom sheet
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('${targetName ?? 'Kullanıcı'} engellendi'),
        backgroundColor: AppColors.success,
      ));
      ctx.pop(); // go back from profile
    }
  }

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
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.block, color: AppColors.error),
          title: Text('🚫 Kullanıcıyı engelle',
              style: AppTextStyles.bodyLarge),
          onTap: () => _block(context),
        ),
        ListTile(
          leading:
              const Icon(Icons.flag_outlined, color: AppColors.warning),
          title: Text('⚠️ Rapor et', style: AppTextStyles.bodyLarge),
          onTap: () {
            Navigator.pop(context);
            context.push('/report/$targetUserId');
          },
        ),
        ListTile(
          leading: const Icon(Icons.close, color: AppColors.textTertiary),
          title: Text('İptal', style: AppTextStyles.bodyMedium),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo Carousel (hero)
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
        // Bottom gradient into the panel
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [AppColors.bgBlack, Colors.transparent],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        // Photo indicator bars — top center
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
