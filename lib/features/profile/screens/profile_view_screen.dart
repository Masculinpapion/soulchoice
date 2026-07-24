import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../core/utils/guard_errors.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/profile_provider.dart';
import '../../invitation/providers/my_active_invitation_provider.dart';
import '../../messaging/providers/matches_provider.dart';
import '../../invitation/providers/my_applications_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/photo_focus.dart';

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
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
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
              child: Text(AppLocalizations.of(context)!.error_generic,
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
            final bio = user['bio'] as String?;
            final job = user['job'] as String?;
            final education = user['education'] as String?;
            final city = user['city'] as Map<String, dynamic>?;
            final lang = ref.watch(localeProvider)?.languageCode;
            String? _localizedCity;
            if (lang == 'ru') _localizedCity = city?['name_ru'] as String?;
            else if (lang == 'tr') _localizedCity = city?['name_tr'] as String?;
            else _localizedCity = city?['name_en'] as String?;
            final cityName = _localizedCity ?? city?['name'] as String? ?? '';
            final interests = ((user['interests'] as List?)?.cast<String>() ?? [])
                .toSet().toList();
            // Galeri garantisi: yalnız bu kullanıcıya ait fotoğraflar render
            // edilir — provider/cache ne dönerse dönsün yabancı foto elenir.
            final photos = (photosAsync.asData?.value ?? [])
                .where((p) => p['user_id'] == userId)
                .toList();

            Widget trailing;
            if (isOwnProfile) {
              trailing = _GlassIconButton(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              );
            } else if (currentUid != null) {
              trailing = _GlassIconButton(
                icon: Icons.more_horiz,
                onTap: () => _showActionSheet(context, userId),
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
                        name: name,
                        age: age,
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
                              _MyInvitationSection(),
                              const SizedBox(height: 28),
                              const _MyApplicationsSection(),
                              const _SubscriptionEntryCard(),
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
                                                    as String, l10n,
                                                user['gender'] as String? ?? 'other'),
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
                              padding: const EdgeInsets.only(top: 8, bottom: 32),
                              child: Builder(builder: (ctx) {
                                final extra = GoRouterState.of(ctx).extra;
                                final appCtx = extra is Map<String, dynamic> ? extra : null;
                                final applicationId = appCtx?['applicationId'] as String?;
                                final invitationId = appCtx?['invitationId'] as String?;
                                final applicantName = appCtx?['applicantName'] as String?;

                                if (applicationId != null && invitationId != null) {
                                  return _ApplicantActions(
                                    applicationId: applicationId,
                                    invitationId: invitationId,
                                    applicantId: userId,
                                    applicantName: applicantName ?? '',
                                  );
                                }

                                // Eşleşilen kişinin profilinden sohbete net giriş
                                if (!isOwnProfile && currentUid != null) {
                                  final existingMatchId = ref
                                      .watch(matchWithUserProvider(userId))
                                      .asData
                                      ?.value;
                                  if (existingMatchId != null) {
                                    return _EditorialCTA(
                                      label: l10n.profile_view_cta_message,
                                      onTap: () => context.push(
                                        '/chat/$existingMatchId',
                                        extra: {
                                          'name': name,
                                          'age': age,
                                          'photoUrl': photos.isNotEmpty
                                              ? photos[0]['url'] as String?
                                              : null,
                                        },
                                      ),
                                    );
                                  }
                                }

                                return _EditorialCTA(
                                  label: isOwnProfile
                                      ? l10n.profile_view_cta_edit
                                      : l10n.profile_view_cta_come,
                                  onTap: isOwnProfile
                                      ? () => context.push('/profile/edit')
                                      : () => context.pop(),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Pinned top bar (scroll ile kaybolmaz) ──────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isOwnProfile)
                            _GlassIconButton(
                              icon: Icons.arrow_back_ios_new,
                              onTap: () => context.pop(),
                            )
                          else
                            const SizedBox(width: 40),
                          trailing,
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
      route ??= '/profile/edit';
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
      route ??= '/profile/edit';
    }

    // Interests: 15 pts
    if (interests.isNotEmpty) {
      score += 15;
    } else {
      hint ??= l10n.profile_view_hint_interests;
      route ??= '/profile/edit';
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
      route ??= '/profile/edit';
    }

    return _ProfileCompletionCard(
      score: score,
      hint: score == 100 ? null : hint,
      onTap: route != null ? () => context.push(route!, extra: 'edit') : null,
    );
  }

  String _questionLabel(String key, AppLocalizations l10n, String gender) {
    switch (key) {
      case 'favorite_restaurant': return l10n.profile_setup_prompt_favorite_restaurant;
      case 'last_book': return l10n.profile_setup_prompt_last_book(gender);
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
  final String name;
  final int age;
  final String cityName;
  final String? job;
  final String? education;

  const _HeroSection({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
    required this.name,
    required this.age,
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
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              onPageChanged: (i) {
                setState(() => _current = i);
                widget.onPageChanged(i);
              },
              itemBuilder: (context, i) => GestureDetector(
                onTapUp: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    if (_current > 0) {
                      _ctrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  } else {
                    if (_current < widget.photos.length - 1) {
                      _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                },
                child: CachedNetworkImage(
                  imageUrl: widget.photos[i]['url'] as String,
                  fit: BoxFit.cover,
                  alignment: PhotoFocus.of(widget.photos[i]['url'] as String),
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
            child: IgnorePointer(
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
          ),

          // ── c. Bottom fade (5-stop) ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: IgnorePointer(
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
          ),

          // ── d. Aurora glow ────────────────────────────────────────────
          Positioned(
            bottom: -100,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
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
          ),

          // ── e. Foto nokta göstergesi (back/trailing pinned bara taşındı) ──
          if (widget.photos.length > 1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: _DotIndicator(
                      count: widget.photos.length,
                      current: _current,
                    ),
                  ),
                ),
              ),
            ),

          // ── f. Identity overlay ───────────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
            label,
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
                    question,
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
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(Rect.fromLTRB(b.left - 4, b.top - 2, b.right + 14, b.bottom + 4)),
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
    final targetData = await Supabase.instance.client
        .from('users')
        .select('gender')
        .eq('id', targetUserId)
        .maybeSingle();
    final targetGender = targetData?['gender'] as String? ?? 'other';
    await Supabase.instance.client.from('blocks').upsert({
      'blocker_id': uid,
      'blocked_id': targetUserId,
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.profile_view_blocked_snack(targetName ?? l10n.profile_view_anonymous_user, targetGender)),
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

// ── Başvuranlar için Seç / Reddet butonları ──────────────────────────────────
class _ApplicantActions extends StatefulWidget {
  final String applicationId;
  final String invitationId;
  final String applicantId;
  final String applicantName;

  const _ApplicantActions({
    required this.applicationId,
    required this.invitationId,
    required this.applicantId,
    required this.applicantName,
  });

  @override
  State<_ApplicantActions> createState() => _ApplicantActionsState();
}

class _ApplicantActionsState extends State<_ApplicantActions> {
  bool _loading = false;

  Future<void> _select() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    try {
      // 24.07 E2E: timeout'suz await, yanıt kaybolduğunda sonsuz spinner
      // bırakıyordu (sunucu işlemi bitirmişti) — timeout + kurtarma eklendi.
      final matchId = await client.rpc('match_and_select', params: {
        'p_application_id': widget.applicationId,
        'p_invitation_id': widget.invitationId,
      }).timeout(const Duration(seconds: 20)) as String;

      // Başvuru sahibine "seçildin" bildirimi gönder
      _sendSelectedNotification(widget.applicantId, matchId);
      _openChat(matchId);
    } on TimeoutException {
      // Sunucu işlemi bitirmiş olabilir — durumu sorgula, accepted ise kurtar
      try {
        final app = await client
            .from('applications')
            .select('status')
            .eq('id', widget.applicationId)
            .maybeSingle();
        if (app?['status'] == 'accepted') {
          final match = await client
              .from('matches')
              .select('id')
              .eq('invitation_id', widget.invitationId)
              .maybeSingle();
          if (match != null) {
            _openChat(match['id'] as String);
            return;
          }
        }
      } catch (_) {}
      _showSelectError(TimeoutException('match_and_select'));
    } catch (e) {
      // 24.07 denetim: sessiz başarısızlık — sahibi bilgilendir (guard token'ları dahil)
      _showSelectError(e);
    }
  }

  void _openChat(String matchId) {
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(
      '/chat/$matchId',
      extra: {'name': widget.applicantName},
    );
  }

  void _showSelectError(Object e) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GuardError.from(context, e)?.message ??
            AppLocalizations.of(context)!.error_generic)));
  }

  Future<void> _sendSelectedNotification(String applicantId, String matchId) async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final myName = uid == null
          ? ''
          : (await client.from('users').select('name').eq('id', uid).maybeSingle())?['name']
                  as String? ??
              '';
      // Metin sunucu şablonundan ALICININ dilinde üretilir; buradaki RU fallback.
      await client.functions.invoke('send-notification', body: {
        'user_id': applicantId,
        'title': '🎉 Тебя выбрали!',
        'body': 'Твоя заявка принята. Открой чат!',
        'data': {
          'type': 'selected',
          'invitation_id': widget.invitationId,
          // Push'a dokununca doğrudan sohbete düşsün (main.dart deep link)
          'match_id': matchId,
        },
        'template': {'name': myName},
      });
    } catch (_) {}
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('applications').update({
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.applicationId);
    } catch (_) {
      // 24.07 denetim: başarısız red, başarı gibi kapanmasın
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.error_generic)));
      }
      return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _loading ? null : _reject,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(AppLocalizations.of(context)!.btn_reject),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _select,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(AppLocalizations.of(context)!.applicants_select_btn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Invitation Section — profilde davetiye yönetim kartı
// ─────────────────────────────────────────────────────────────────────────────

class _MyInvitationSection extends ConsumerWidget {
  String _remainingLabel(Duration d, AppLocalizations l10n) {
    if (d.isNegative) return l10n.profile_inv_expired;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return l10n.profile_inv_hours_left(h);
    return l10n.profile_inv_minutes_left(m);
  }

  String _category(String? key, AppLocalizations l10n) {
    switch (key) {
      case 'food':
        return l10n.category_food;
      case 'bar':
        return l10n.category_bar;
      case 'concert':
        return l10n.category_concert;
      case 'travel':
        return l10n.category_travel;
      case 'culture':
        return l10n.category_culture;
      case 'cinema':
        return l10n.category_cinema;
      case 'theater':
        return l10n.category_theater;
      case 'coffee':
        return l10n.category_coffee;
      default:
        return key ?? '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncInv = ref.watch(myActiveInvitationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profile_inv_section, style: AuroraTheme.monoLabel),
        const SizedBox(height: 14),
        asyncInv.when(
          loading: () => Container(
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),
          ),
          error: (e, _) => Text(AppLocalizations.of(context)!.error_generic,
              style: TextStyle(
                  color: AuroraTheme.textSecondary, fontFamily: 'Manrope')),
          data: (invs) {
            if (invs.isEmpty) {
              return _CreateInvitationCta(
                label: l10n.profile_inv_create_cta,
                emptyTitle: l10n.profile_inv_empty_title,
              );
            }
            return Column(
              children: [
                for (var i = 0; i < invs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildCard(context, l10n, invs[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> inv,
  ) {
    final id = inv['id'] as String;
            final isRequest = (inv['flow_type'] as String?) == 'request';
            final count = inv['application_count'] as int? ?? 0;
            final photoUrl = inv['owner_photo_url'] as String?;
            final categoryKey = inv['category'] as String?;
            final title = (inv['title'] as String?)?.trim() ?? '';
            final expiresAt =
                DateTime.parse(inv['expires_at'] as String).toLocal();
            final remaining = expiresAt.difference(DateTime.now());

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => GoRouter.of(context).push('/invitation/$id'),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF2D55).withOpacity(0.12),
                        const Color(0xFF2D7FFF).withOpacity(0.12),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  alignment: PhotoFocus.of(photoUrl),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.white54),
                                  ),
                                )
                              : Container(
                                  color: Colors.white.withOpacity(0.05),
                                  child: const Icon(Icons.event_outlined,
                                      color: Colors.white54),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _category(categoryKey, l10n),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11,
                                    fontFamily: 'JetBrainsMono',
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isRequest
                                      ? Icons.explore_rounded
                                      : Icons.wine_bar_rounded,
                                  size: 13,
                                  color: isRequest
                                      ? const Color(0xFF2D7FFF)
                                      : const Color(0xFFFF2D55),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title.isNotEmpty
                                  ? title
                                  : _category(categoryKey, l10n),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Manrope',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.profile_inv_applicants(count)} · ${_remainingLabel(remaining, l10n)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.white.withOpacity(0.7)),
                    ],
                  ),
                ),
              ),
            );
  }
}

class _CreateInvitationCta extends StatelessWidget {
  final String label;
  final String emptyTitle;
  const _CreateInvitationCta({required this.label, required this.emptyTitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/invitation/create'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFF2D7FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2D55).withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emptyTitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────
// Subscription Entry — profilde Abonelik yönetimine giriş (F2-2: ≤2 tık)
// ─────────────────────────────────────────────────────────────────
class _SubscriptionEntryCard extends StatelessWidget {
  const _SubscriptionEntryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/subscription'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AuroraTheme.glassBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AuroraTheme.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                ),
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.sub_title,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: AuroraTheme.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Başvurularım — başvuranın akıbet takibi (🟠2, 15.07). Boşsa hiç görünmez.
// ─────────────────────────────────────────────────────────────────────────────

class _MyApplicationsSection extends ConsumerWidget {
  const _MyApplicationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appsAsync = ref.watch(myApplicationsListProvider);
    final apps = appsAsync.asData?.value ?? [];
    if (apps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditSectionHeader(label: l10n.profile_my_applications),
        const SizedBox(height: 16),
        ...apps.map((a) {
          final inv = a['invitation'] as Map<String, dynamic>?;
          final ownerName =
              (inv?['owner'] as Map<String, dynamic>?)?['name'] as String?;
          final title = inv?['title'] as String? ?? '—';
          final status = a['status'] as String? ?? 'pending';
          final invStatus = inv?['status'] as String?;
          // pending + ilan kapandıysa fiilen "seçim yapılmadı"
          final effective = (status == 'pending' && invStatus == 'closed')
              ? 'expired'
              : status;
          final (chipText, chipColor) = switch (effective) {
            'accepted' => (l10n.app_status_accepted, const Color(0xFF34C759)),
            'rejected' => (l10n.app_status_rejected, AuroraTheme.textMuted),
            'expired' => (l10n.app_status_expired, AuroraTheme.textMuted),
            _ => (l10n.app_status_pending, const Color(0xFFFFC02D)),
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: inv == null
                  ? null
                  : () => context.push('/invitation/${inv['id']}'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AuroraTheme.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AuroraTheme.glassBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          if (ownerName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              ownerName,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                color: AuroraTheme.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                        border:
                            Border.all(color: chipColor.withOpacity(0.45)),
                      ),
                      child: Text(
                        chipText,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
      ],
    );
  }
}
