import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/profile_provider.dart';

class ProfileViewScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileViewScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends ConsumerState<ProfileViewScreen> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final profileAsync = ref.watch(userProfileProvider(userId));
    final photosAsync = ref.watch(userPhotosProvider(userId));
    final promptsAsync = ref.watch(userPromptsProvider(userId));
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUid == userId;
    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF050709),
        body: profileAsync.when(
          loading: () => AmbientBackground(
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(AuroraTheme.auroraRed),
                ),
              ),
            ),
          ),
          error: (e, _) => AmbientBackground(
            child: Center(
              child: Text('$e',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      color: AuroraTheme.textSecondary)),
            ),
          ),
          data: (user) {
            if (user == null) {
              return AmbientBackground(
                child: Center(
                  child: Text(l10n.profile_view_not_found,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          color: AuroraTheme.textSecondary)),
                ),
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
            final interests = ((user['interests'] as List?)?.cast<String>() ?? [])
                .toSet().toList();
            final photos = photosAsync.asData?.value ?? [];

            Widget trailing;
            if (isOwnProfile) {
              trailing = _GlassIconButton(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              );
            } else if (currentUid != null) {
              trailing = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FavoriteButton(targetUserId: userId),
                  const SizedBox(width: 4),
                  _GlassIconButton(
                    icon: Icons.more_horiz,
                    onTap: () => _showActionSheet(context, userId),
                  ),
                ],
              );
            } else {
              trailing = const SizedBox(width: 40);
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero %74.9 ────────────────────────────────────
                      _HeroSection(
                        key: photos.isNotEmpty
                            ? ValueKey('hero-${photos[0]['id']}')
                            : const ValueKey('hero-empty'),
                        photos: photos,
                        initialIndex: 0,
                        onPageChanged: (i) =>
                            setState(() => _photoIndex = i),
                        onBack: () => context.pop(),
                        trailing: trailing,
                        name: name,
                        age: age,
                        verified: verified,
                        cityName: cityName,
                        job: job,
                        education: education,
                      ),

                      // ── Content ───────────────────────────────────────
                      Container(
                        color: const Color(0xFF050709),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profil tamamlanma — sadece kendi profili
                            if (isOwnProfile) ...[
                              _buildCompletionCard(
                                context: context,
                                user: user,
                                photos: photos,
                                bio: bio,
                                interests: interests,
                                selfieStatus: selfieStatus,
                                promptsAsync: promptsAsync,
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Bio
                            if (bio != null && bio.isNotEmpty) ...[
                              _EditBio(bio: bio),
                              const SizedBox(height: 36),
                            ],

                            // İlgi Alanları
                            if (interests.isNotEmpty) ...[
                              _EditSectionHeader(
                                  label: l10n.profile_view_section_interests),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                  interests.length,
                                  (i) => _EditInterestPill(
                                    label: _interestLabel(interests[i], l10n),
                                    isFirst: i == 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                            ],

                            // İfadeler
                            promptsAsync.maybeWhen(
                              data: (prompts) {
                                final list = (prompts as List)
                                    .cast<Map<String, dynamic>>()
                                    .where((p) {
                                  final a = p['answer'] as String?;
                                  return a != null && a.isNotEmpty;
                                }).toList();
                                if (list.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _EditSectionHeader(
                                        label: l10n.profile_view_section_prompts),
                                    const SizedBox(height: 16),
                                    ...list.asMap().entries.map((e) =>
                                        Padding(
                                          padding: EdgeInsets.only(
                                              bottom: e.key <
                                                      list.length - 1
                                                  ? 12
                                                  : 0),
                                          child: _EditPromptCard(
                                            question: _questionLabel(
                                                e.value['question_key']
                                                    as String, l10n),
                                            answer: e.value['answer']
                                                as String,
                                            index: e.key,
                                          ),
                                        )),
                                    const SizedBox(height: 32),
                                  ],
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),

                            // CTA
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 32),
                              child: _EditorialCTA(
                                label: isOwnProfile
                                    ? l10n.profile_view_cta_edit
                                    : l10n.profile_view_cta_come,
                                onTap: isOwnProfile
                                    ? () =>
                                        context.push('/profile/setup', extra: 'edit')
                                    : () => context.pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionCard({
    required BuildContext context,
    required Map<String, dynamic> user,
    required List<Map<String, dynamic>> photos,
    required String? bio,
    required List<String> interests,
    required String selfieStatus,
    required AsyncValue promptsAsync,
  }) {
    final l10n = AppLocalizations.of(context)!;
    int score = 0;
    String? hint;
    String? route;

    // Name & age: 20 pts
    final hasName = (user['name'] as String?)?.isNotEmpty == true;
    final hasAge = (user['age'] as int?) != null;
    if (hasName && hasAge) {
      score += 20;
    } else {
      hint ??= l10n.profile_view_hint_name_age;
      route ??= '/profile/setup';
    }

    // Photo: 20 pts
    if (photos.isNotEmpty) {
      score += 20;
    } else {
      hint ??= l10n.profile_view_hint_photo;
      route ??= '/profile/photos';
    }

    // Bio: 15 pts
    if (bio != null && bio.isNotEmpty) {
      score += 15;
    } else {
      hint ??= l10n.profile_view_hint_bio;
      route ??= '/profile/setup';
    }

    // Interests: 15 pts
    if (interests.isNotEmpty) {
      score += 15;
    } else {
      hint ??= l10n.profile_view_hint_interests;
      route ??= '/profile/setup';
    }

    // Selfie approved: 20 pts
    if (selfieStatus == 'approved') {
      score += 20;
    } else {
      hint ??= selfieStatus == 'pending' ? l10n.profile_view_hint_selfie_pending : l10n.profile_view_hint_selfie_upload;
      route ??= selfieStatus == 'pending' ? null : '/profile/selfie';
    }

    // Prompt: 10 pts
    final promptList = promptsAsync.asData?.value as List?;
    final hasPrompt = promptList?.any(
          (p) => ((p as Map<String, dynamic>)['answer'] as String?)?.isNotEmpty == true,
        ) == true;
    if (hasPrompt) {
      score += 10;
    } else {
      hint ??= l10n.profile_view_hint_prompt;
      route ??= '/profile/setup';
    }

    return _ProfileCompletionCard(
      score: score,
      hint: score == 100 ? null : hint,
      onTap: route != null ? () => context.push(route!, extra: 'edit') : null,
    );
  }

  String _questionLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'favorite_restaurant': return l10n.profile_setup_prompt_favorite_restaurant;
      case 'last_book': return l10n.profile_setup_prompt_last_book;
      case 'perfect_evening': return l10n.profile_setup_prompt_perfect_evening;
      case 'travel_dream': return l10n.profile_setup_prompt_travel_dream;
      default: return key;
    }
  }

  void _showActionSheet(BuildContext context, String targetUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ActionSheet(targetUserId: targetUserId, targetName: null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Completion Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCompletionCard extends StatelessWidget {
  final int score;
  final String? hint;
  final VoidCallback? onTap;

  const _ProfileCompletionCard({required this.score, this.hint, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = score / 100.0;
    final color = score == 100
        ? AuroraTheme.auroraBlue
        : score >= 60
            ? AuroraTheme.auroraRed
            : const Color(0xFFFFB800);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.profile_view_completion(score),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    if (hint != null && onTap != null)
                      Row(
                        children: [
                          Text(
                            hint!,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 11, color: Colors.white.withOpacity(0.3)),
                        ],
                      )
                    else if (hint != null)
                      Text(
                        hint!,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 3,
                    color: Colors.white.withOpacity(0.08),
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: score == 100
                                ? [AuroraTheme.auroraBlue, AuroraTheme.auroraBlue]
                                : [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                          ),
                          borderRadius: BorderRadius.circular(3),
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

// ─────────────────────────────────────────────────────────────────────────────
// Hero Section — %74.9 ekran, editorial identity overlay
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final Widget trailing;
  final String name;
  final int age;
  final bool verified;
  final String cityName;
  final String? job;
  final String? education;

  const _HeroSection({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.trailing,
    required this.name,
    required this.age,
    required this.verified,
    required this.cityName,
    this.job,
    this.education,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didUpdateWidget(_HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photos.isNotEmpty &&
        (oldWidget.photos.isEmpty ||
            oldWidget.photos[0]['id'] != widget.photos[0]['id'])) {
      _current = 0;
      _ctrl.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroH = MediaQuery.of(context).size.height * 0.749;

    // Meta items: city · job · education (skip nulls/empties)
    final metaItems = <String>[
      if (widget.cityName.isNotEmpty) widget.cityName,
      if (widget.job != null && widget.job!.isNotEmpty) widget.job!,
      if (widget.education != null && widget.education!.isNotEmpty)
        widget.education!,
    ];

    return SizedBox(
      height: heroH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── a. Fotoğraf PageView ──────────────────────────────────────
          if (widget.photos.isNotEmpty)
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) {
                setState(() => _current = i);
                widget.onPageChanged(i);
              },
              itemBuilder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.photos.length > 1
                    ? (details) {
                        final w = MediaQuery.of(context).size.width;
                        if (details.localPosition.dx < w / 2) {
                          if (_current > 0) {
                            _ctrl.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          }
                        } else {
                          if (_current < widget.photos.length - 1) {
                            _ctrl.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          }
                        }
                      }
                    : null,
                child: CachedNetworkImage(
                  imageUrl: widget.photos[i]['url'] as String,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorWidget: (_, __, ___) => _NoPhotoPlaceholder(),
                ),
              ),
            )
          else
            _NoPhotoPlaceholder(),

          // ── b. Top scrim ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55050709),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── c. Bottom fade (5-stop) ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.30, 0.60, 0.85, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x1A050709),
                    Color(0x66050709),
                    Color(0xCC050709),
                    Color(0xFF050709),
                  ],
                ),
              ),
            ),
          ),

          // ── d. Aurora glow ────────────────────────────────────────────
          Positioned(
            bottom: -100,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  stops: [0.0, 0.4, 0.7],
                  colors: [
                    Color(0x26FF2D55),
                    Color(0x142D7FFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── e. Top bar ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: widget.onBack,
                    ),
                    if (widget.photos.length > 1)
                      _DotIndicator(
                        count: widget.photos.length,
                        current: _current,
                      )
                    else
                      const SizedBox(width: 40),
                    widget.trailing,
                  ],
                ),
              ),
            ),
          ),

          // ── f. Identity overlay ───────────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // İsim + verified badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${widget.name}, ${widget.age}',
                        overflow: TextOverflow.ellipsis,
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
                      ),
                    ),
                    if (widget.verified) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF2D55),
                              Color(0xFF2D7FFF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AuroraTheme.auroraRed.withOpacity(0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                      ),
                    ],
                  ],
                ),

                // Meta row: city · job · education
                if (metaItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (int i = 0; i < metaItems.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          metaItems[i].toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.16 * 11,
                            color: Colors.white.withOpacity(0.78),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Indicator — gradient pill aktif, küçük daire pasif
// ─────────────────────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: isActive ? AuroraTheme.redBlueGradient : null,
              color: isActive ? null : Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(isActive ? 3 : 50),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AuroraTheme.auroraRed.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Editorial Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _EditSectionHeader extends StatelessWidget {
  final String label;
  const _EditSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AuroraTheme.auroraRed.withOpacity(0.6),
                  AuroraTheme.auroraBlue.withOpacity(0.6),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18 * 11,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Editorial Bio — sol gradient çizgi + 18px Fraunces italic
// ─────────────────────────────────────────────────────────────────────────────
class _EditBio extends StatelessWidget {
  final String bio;
  const _EditBio({required this.bio});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: AuroraTheme.redBlueGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                bio,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  height: 1.55,
                  letterSpacing: -0.005 * 18,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
            ),
          ],
        ),
      );
}

String _interestLabel(String key, AppLocalizations l10n) {
  switch (key) {
    case 'art': return l10n.profile_setup_interest_art;
    case 'music': return l10n.profile_setup_interest_music;
    case 'sports': return l10n.profile_setup_interest_sports;
    case 'books': return l10n.profile_setup_interest_books;
    case 'travel': return l10n.profile_setup_interest_travel;
    case 'food': return l10n.profile_setup_interest_food;
    case 'film': return l10n.profile_setup_interest_film;
    case 'theatre': return l10n.profile_setup_interest_theatre;
    case 'dance': return l10n.profile_setup_interest_dance;
    case 'yoga': return l10n.profile_setup_interest_yoga;
    case 'photography': return l10n.profile_setup_interest_photography;
    case 'games': return l10n.profile_setup_interest_games;
    case 'technology': return l10n.profile_setup_interest_technology;
    case 'nature': return l10n.profile_setup_interest_nature;
    case 'history': return l10n.profile_setup_interest_history;
    case 'fashion': return l10n.profile_setup_interest_fashion;
    default: return key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editorial Interest Pill — glass blur, gradient ilk pill
// ─────────────────────────────────────────────────────────────────────────────
class _EditInterestPill extends StatelessWidget {
  final String label;
  final bool isFirst;
  const _EditInterestPill({required this.label, required this.isFirst});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: isFirst
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x2EFF2D55),
                        Color(0x2E2D7FFF),
                      ],
                    )
                  : null,
              color: isFirst ? null : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isFirst
                    ? const Color(0x59FF2D55)
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Editorial Prompt Card — glass blur, sol çizgi, 22px cevap
// ─────────────────────────────────────────────────────────────────────────────
class _EditPromptCard extends StatelessWidget {
  final String question;
  final String answer;
  final int index;
  const _EditPromptCard(
      {required this.question, required this.answer, this.index = 0});

  // Her kart farklı aurora renk çifti — döngüsel
  static const _lineGradients = [
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)],   // kırmızı → mavi
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2D7FFF), Color(0xFF8B5CF6)],   // mavi → violet
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF8B5CF6), Color(0xFFFFB800)],   // violet → gold
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFB800), Color(0xFFFF2D55)],   // gold → kırmızı
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lineGrad = _lineGradients[index % _lineGradients.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.fromLTRB(20, 18, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.14 * 10,
                      color: Colors.white.withOpacity(0.42),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    answer,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      fontSize: 22,
                      height: 1.3,
                      letterSpacing: -0.01 * 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Sol çizgi — aurora gradient, her kart farklı renk
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  gradient: lineGrad,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editorial CTA — tam genişlik gradient pill
// ─────────────────────────────────────────────────────────────────────────────
class _EditorialCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EditorialCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)],
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AuroraTheme.auroraRed.withOpacity(0.28),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AuroraTheme.auroraBlue.withOpacity(0.18),
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
                letterSpacing: 0.08 * 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Aşağıdaki widget'lar korundu — değiştirilmedi
// ─────────────────────────────────────────────────────────────────────────────
class _NoPhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AuroraTheme.bgDeep,
        child: Center(
          child: ShaderMask(
            shaderCallback: (b) =>
                AuroraTheme.redBlueGradient.createShader(b),
            child: const Icon(Icons.person_outline,
                size: 80, color: Colors.white),
          ),
        ),
      );
}

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
                color: Colors.black.withOpacity(0.35),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
}

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
                    ? AuroraTheme.auroraRed.withOpacity(0.20)
                    : Colors.black.withOpacity(0.35),
                border: Border.all(
                  color: _isFavorite!
                      ? AuroraTheme.auroraRed.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Icon(
                _isFavorite!
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _isFavorite!
                    ? AuroraTheme.auroraRed
                    : Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final String targetUserId;
  final String? targetName;
  const _ActionSheet({required this.targetUserId, this.targetName});

  Future<void> _block(BuildContext ctx) async {
    final l10n = AppLocalizations.of(ctx)!;
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.profile_view_action_block,
          style: const TextStyle(
              fontFamily: 'Fraunces',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: Colors.white),
        ),
        content: Text(
          l10n.profile_view_block_confirm_body,
          style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: AuroraTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.profile_view_action_block_cancel,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profile_view_action_block_confirm,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: AuroraTheme.auroraRed,
                    fontWeight: FontWeight.w700)),
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.profile_view_blocked_snack(targetName ?? l10n.profile_view_anonymous_user)),
        backgroundColor: const Color(0xFF10B981),
      ));
      ctx.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12).withOpacity(0.90),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border:
                Border(top: BorderSide(color: AuroraTheme.glassBorder)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: AuroraTheme.redBlueGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.block,
                      color: AuroraTheme.auroraRed),
                  title: Text(l10n.profile_view_action_block,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: Colors.white)),
                  onTap: () => _block(context),
                ),
                ListTile(
                  leading: Icon(Icons.flag_outlined,
                      color: AuroraTheme.auroraGold),
                  title: Text(l10n.profile_view_action_report,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/report/$targetUserId');
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.close, color: AuroraTheme.textMuted),
                  title: Text(l10n.profile_view_action_cancel,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: AuroraTheme.textSecondary)),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) => GestureDetector(
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
