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
      backgroundColor: AppColors.bgDeep,
      body: AmbientBackground(
        child: profileAsync.when(
          loading: () => const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
              ),
            ),
          ),
          error: (e, _) =>
              Center(child: Text('$e', style: AppTextStyles.bodyMedium)),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text('Profil bulunamadı',
                    style: AppTextStyles.bodyMedium),
              );
            }

            final name = user['name'] as String? ?? '—';
            final age = user['age'] as int? ?? 0;
            final selfieStatus =
                user['selfie_status'] as String? ?? 'none';
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

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero ────────────────────────────────────────────────
                  _HeroSection(
                    photos: photos,
                    name: name,
                    age: age,
                    verified: verified,
                    cityName: cityName,
                    job: job,
                    education: education,
                    isOwnProfile: isOwnProfile,
                    currentUid: currentUid,
                    userId: userId,
                    onBack: () => context.pop(),
                    onSettings: () => context.push('/settings'),
                    onReport: () => _showActionSheet(context, userId),
                    onPhotoTap: (i) =>
                        _openPhotoViewer(context, photos, i),
                  ),

                  // ── Content ─────────────────────────────────────────────
                  Container(
                    color: AppColors.bgDeep,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bio
                        if (bio != null && bio.isNotEmpty) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 28, 24, 0),
                            child: _BioPullQuote(text: bio),
                          ),
                          const SizedBox(height: 36),
                        ] else
                          const SizedBox(height: 28),

                        // Interests
                        if (interests.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: const _SectionHeader(
                                label: 'İlgi Alanları'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              itemCount: interests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => _InterestPill(
                                label: interests[i],
                                isAccent: i == 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],

                        // Prompts
                        promptsAsync.maybeWhen(
                          data: (prompts) {
                            if (prompts.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const _SectionHeader(label: 'İfadeler'),
                                  const SizedBox(height: 16),
                                  ...prompts.map((p) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 12),
                                        child: _PromptCard(
                                          question: _questionLabel(
                                              p['question_key'] as String),
                                          answer: p['answer'] as String? ??
                                              '',
                                        ),
                                      )),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),

                        // CTA
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            MediaQuery.of(context).padding.bottom + 32,
                          ),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _questionLabel(String key) {
    const labels = {
      'favorite_restaurant': 'Favori Restoranım',
      'last_book': 'Son Okuduğum Kitap',
      'perfect_evening': 'Mükemmel Bir Akşam',
      'travel_dream': 'Hayalimdeki Seyahat',
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
      builder: (_) =>
          _ActionSheet(targetUserId: targetUserId, targetName: null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Section
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final String name;
  final int age;
  final bool verified;
  final String cityName;
  final String? job;
  final String? education;
  final bool isOwnProfile;
  final String? currentUid;
  final String userId;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onReport;
  final void Function(int) onPhotoTap;

  const _HeroSection({
    required this.photos,
    required this.name,
    required this.age,
    required this.verified,
    required this.cityName,
    this.job,
    this.education,
    required this.isOwnProfile,
    required this.currentUid,
    required this.userId,
    required this.onBack,
    required this.onSettings,
    required this.onReport,
    required this.onPhotoTap,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final heroH = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: heroH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo carousel
          _buildCarousel(),

          // Top scrim (gradient for legibility of buttons)
          IgnorePointer(
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99050709), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom fade into bgDeep
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: heroH * 0.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF050709),
                      Color(0xCC050709),
                      Color(0x55050709),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Top bar: back + dots + action button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: widget.onBack,
                    ),
                    const Spacer(),
                    if (widget.photos.length > 1)
                      _DotIndicator(
                        count: widget.photos.length,
                        active: _current,
                      ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.isOwnProfile &&
                            widget.currentUid != null) ...[
                          _FavoriteButton(targetUserId: widget.userId),
                          const SizedBox(width: 8),
                        ],
                        _GlassIconButton(
                          icon: widget.isOwnProfile
                              ? Icons.settings_outlined
                              : Icons.more_horiz,
                          onTap: widget.isOwnProfile
                              ? widget.onSettings
                              : widget.onReport,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Identity overlay — bottom of hero
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${widget.name}, ${widget.age}',
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          fontSize: 44,
                          letterSpacing: -0.88,
                          height: 1.05,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 24,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.verified) ...[
                      const SizedBox(width: 12),
                      _GradientVerifiedBadge(size: 24),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _MetaLine(
                  cityName: widget.cityName,
                  job: widget.job,
                  education: widget.education,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    if (widget.photos.isEmpty) {
      return Container(
        color: AppColors.bgCard,
        child: const Center(
          child: Icon(Icons.person_outline,
              size: 80, color: AppColors.textTertiary),
        ),
      );
    }

    return PageView.builder(
      itemCount: widget.photos.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (_, i) {
        final url = widget.photos[i]['url'] as String;
        return GestureDetector(
          onTap: () => widget.onPhotoTap(i),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorWidget: (_, __, ___) => Container(
              color: AppColors.bgCard,
              child: const Icon(Icons.person_outline,
                  size: 80, color: AppColors.textTertiary),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int active;
  const _DotIndicator({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return Padding(
          padding: EdgeInsets.only(right: i < count - 1 ? 6 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isActive ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isActive ? 3 : 100),
              gradient: isActive ? AppColors.primaryGradient : null,
              color: isActive ? null : Colors.white.withOpacity(0.35),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.gradientStart.withOpacity(0.5),
                        blurRadius: 10,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient Verified Badge
// ─────────────────────────────────────────────────────────────────────────────

class _GradientVerifiedBadge extends StatelessWidget {
  final double size;
  const _GradientVerifiedBadge({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.gradientStart.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.check,
          color: Colors.white,
          size: size * 0.55,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta Line (city · job · education)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaLine extends StatelessWidget {
  final String cityName;
  final String? job;
  final String? education;
  const _MetaLine(
      {required this.cityName, required this.job, required this.education});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (cityName.isNotEmpty) cityName,
      if (job != null && job!.isNotEmpty) job!,
      if (education != null && education!.isNotEmpty) education!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 0,
      runSpacing: 4,
      children: () {
        final widgets = <Widget>[];
        for (var i = 0; i < parts.length; i++) {
          widgets.add(Text(
            parts[i].toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.176,
              color: Color(0xC7FFFFFF),
            ),
          ));
          if (i < parts.length - 1) {
            widgets.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: const TextStyle(
                  color: Color(0x66FFFFFF),
                  fontSize: 11,
                ),
              ),
            ));
          }
        }
        return widgets;
      }(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bio Pull-Quote
// ─────────────────────────────────────────────────────────────────────────────

class _BioPullQuote extends StatelessWidget {
  final String text;
  const _BioPullQuote({required this.text});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                fontSize: 18,
                height: 1.55,
                color: Color(0xE0FFFFFF),
                letterSpacing: -0.09,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header (gradient line + mono label)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.198,
            color: Color(0x8CFFFFFF),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interest Pill
// ─────────────────────────────────────────────────────────────────────────────

class _InterestPill extends StatelessWidget {
  final String label;
  final bool isAccent;
  const _InterestPill({required this.label, this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: isAccent
            ? const LinearGradient(
                colors: [Color(0x2EFF2D55), Color(0x2E2D7FFF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isAccent ? null : AppColors.glassBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isAccent
              ? const Color(0x59E63946)
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(isAccent ? 1.0 : 0.85),
          letterSpacing: -0.065,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prompt Card
// ─────────────────────────────────────────────────────────────────────────────

class _PromptCard extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.14,
                            color: Color(0x6BFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          answer,
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                            fontSize: 22,
                            height: 1.3,
                            color: Colors.white,
                            letterSpacing: -0.22,
                          ),
                        ),
                      ],
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
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x59000000),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Favorite Button
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
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFavorite!
                    ? AppColors.red.withOpacity(0.18)
                    : const Color(0x59000000),
                border: Border.all(
                  color: _isFavorite!
                      ? AppColors.red.withOpacity(0.5)
                      : AppColors.glassBorder,
                ),
              ),
              child: Icon(
                _isFavorite!
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _isFavorite!
                    ? AppColors.red
                    : Colors.white.withOpacity(0.8),
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
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientStart.withOpacity(0.28),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.gradientEnd.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.08,
              ),
            ),
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
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: AppColors.glassBorderBright, width: 1.5),
            color: AppColors.glassBg,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.08,
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-Screen Photo Viewer
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
    _pageController = PageController(initialPage: widget.initialIndex);
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
                    size: 60,
                  ),
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
// Action Sheet (block / report)
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
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
      ctx.pop();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('${targetName ?? 'Kullanıcı'} engellendi'),
        backgroundColor: AppColors.success,
      ));
      ctx.pop();
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
          title: Text('Kullanıcıyı engelle',
              style: AppTextStyles.bodyLarge),
          onTap: () => _block(context),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined,
              color: AppColors.warning),
          title: Text('Rapor et', style: AppTextStyles.bodyLarge),
          onTap: () {
            Navigator.pop(context);
            context.push('/report/$targetUserId');
          },
        ),
        ListTile(
          leading:
              const Icon(Icons.close, color: AppColors.textTertiary),
          title: Text('İptal', style: AppTextStyles.bodyMedium),
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
