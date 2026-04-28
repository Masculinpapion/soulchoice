import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../core/widgets/aurora/glass_card.dart';
import '../../../core/widgets/aurora/glass_pill.dart';
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
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AuroraTheme.bgDeep,
        body: profileAsync.when(
          loading: () => Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              '$e',
              style: TextStyle(
                  fontFamily: AuroraTheme.fontBody,
                  color: AuroraTheme.textSecondary),
            ),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text(
                  'Profil bulunamadı',
                  style: TextStyle(
                      fontFamily: AuroraTheme.fontBody,
                      color: AuroraTheme.textSecondary),
                ),
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

            return Stack(
              children: [
                // ── Scrollable content ───────────────────────────────────
                CustomScrollView(
                  slivers: [
                    // ── Hero — 75% of screen height ───────────────────────
                    // FIX #1 + #2: Wrapper Stack so identity Positioned is
                    // guaranteed inside the SizedBox bounds, not inside
                    // _PhotoHero's internal Stack (which had constraint issues).
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: screenHeight * 0.75,
                        child: Stack(
                          children: [
                            // Photo fills entire hero area
                            Positioned.fill(
                              child: _PhotoHero(
                                photos: photos,
                                currentIndex: _photoIndex,
                                onIndexChanged: (i) =>
                                    setState(() => _photoIndex = i),
                              ),
                            ),
                            // FIX #1: identity is a sibling Positioned —
                            // always clipped to SizedBox height
                            // FIX #2: left:24 right:24 ensures padding
                            Positioned(
                              left: AuroraTheme.spacingXL,
                              right: AuroraTheme.spacingXL,
                              bottom: AuroraTheme.spacingXXL,
                              child: _IdentityOverlay(
                                name: name,
                                age: age,
                                verified: verified,
                                cityName: cityName,
                                job: job,
                                education: education,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Content section ───────────────────────────────────
                    SliverToBoxAdapter(
                      child: _ContentSection(
                        bio: bio,
                        interests: interests,
                        promptsAsync: promptsAsync,
                        topPadding: 28,
                      ),
                    ),

                    // ── CTA ───────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AuroraTheme.spacingXL,
                          AuroraTheme.spacingS,
                          AuroraTheme.spacingXL,
                          bottomPad + kBottomNavigationBarHeight + 20,
                        ),
                        child: _GradientCTA(
                          label: isOwnProfile
                              ? 'Profili Düzenle'
                              : 'Gelmek isterim',
                          onTap: isOwnProfile
                              ? () => context.push('/profile/setup')
                              : () => context.pop(),
                        ),
                      ),
                    ),

                    // FIX #6: bottom clearance so last prompt + CTA are
                    // fully visible above the bottom nav bar.
                    const SliverToBoxAdapter(
                      child: SizedBox(
                          height: AuroraTheme.scrollBottomSafetyHeight),
                    ),
                  ],
                ),

                // ── Fixed overlay: back + action buttons ─────────────────
                Positioned(
                  top: topPad + AuroraTheme.spacingS,
                  left: AuroraTheme.spacingS,
                  right: AuroraTheme.spacingS,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => context.pop(),
                      ),
                      Row(
                        children: [
                          if (!isOwnProfile && currentUid != null) ...[
                            _FavoriteButton(targetUserId: userId),
                            const SizedBox(width: AuroraTheme.spacingXS),
                          ],
                          _GlassIconButton(
                            icon: isOwnProfile
                                ? Icons.settings_outlined
                                : Icons.more_horiz,
                            onTap: isOwnProfile
                                ? () => context.push('/settings')
                                : () => _showActionSheet(context, userId),
                          ),
                        ],
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
// Photo Hero — photo display + swipe gestures + scrim + fade + dots
// Identity overlay is handled by caller (wrapper Stack + Positioned)
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoHero extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const _PhotoHero({
    required this.photos,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  State<_PhotoHero> createState() => _PhotoHeroState();
}

class _PhotoHeroState extends State<_PhotoHero> {
  Offset? _pointerDown;

  void _goNext() {
    if (widget.currentIndex < widget.photos.length - 1) {
      widget.onIndexChanged(widget.currentIndex + 1);
    }
  }

  void _goPrev() {
    if (widget.currentIndex > 0) {
      widget.onIndexChanged(widget.currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photos.isNotEmpty;
    final url = hasPhotos
        ? widget.photos[widget.currentIndex]['url'] as String
        : null;
    final topPad = MediaQuery.of(context).padding.top;

    return Listener(
      onPointerDown: (e) => _pointerDown = e.localPosition,
      onPointerUp: (e) {
        if (_pointerDown == null) return;
        final dx = e.localPosition.dx - _pointerDown!.dx;
        final dy = e.localPosition.dy - _pointerDown!.dy;
        _pointerDown = null;
        if (dy.abs() > dx.abs() && dy.abs() > 8) return;
        if (dx.abs() < 12) {
          final width = MediaQuery.of(context).size.width;
          if (e.localPosition.dx < width * 0.35) {
            _goPrev();
          } else {
            _goNext();
          }
        } else if (dx < -40) {
          _goNext();
        } else if (dx > 40) {
          _goPrev();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Photo ──────────────────────────────────────────────────────
          if (url != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => _NoPhotoPlaceholder(),
              ),
            )
          else
            _NoPhotoPlaceholder(),

          // ── Full-coverage dark overlay — photo barely visible (mockup) ─
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Color(0xB3000000), // 70%
                    Color(0x33000000), // 20%
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.38, 0.60, 0.72],
                ),
              ),
            ),
          ),

          // ── Top scrim — status bar + button legibility ─────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AuroraTheme.bgDeep.withOpacity(0.60),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom fade — photo melts into bgDeep ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AuroraTheme.bgDeep,
                    AuroraTheme.bgDeep.withOpacity(0.88),
                    AuroraTheme.bgDeep.withOpacity(0.55),
                    AuroraTheme.bgDeep.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.15, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── Dot indicator — top center (preserved ✓) ───────────────────
          if (widget.photos.length > 1)
            Positioned(
              top: topPad + 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (i) {
                  final isActive = i == widget.currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: isActive ? 22.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        gradient:
                            isActive ? AuroraTheme.redBlueGradient : null,
                        color: isActive
                            ? null
                            : Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color:
                                      AuroraTheme.auroraRed.withOpacity(0.50),
                                  blurRadius: AuroraTheme.spacingS,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Identity Overlay — name, age, verified badge, meta line
// Rendered as Positioned inside wrapper Stack, not inside _PhotoHero.
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityOverlay extends StatelessWidget {
  final String name;
  final int age;
  final bool verified;
  final String cityName;
  final String? job;
  final String? education;

  const _IdentityOverlay({
    required this.name,
    required this.age,
    required this.verified,
    required this.cityName,
    this.job,
    this.education,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                '$name, $age',
                style: TextStyle(
                  fontFamily: AuroraTheme.fontDisplay,
                  fontStyle: FontStyle.italic,
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.88, // -0.02em @ 44px
                  color: Colors.white,
                  height: 1.05,
                  shadows: const [
                    Shadow(blurRadius: 24, color: Colors.black87),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (verified) ...[
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AuroraTheme.redBlueGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AuroraTheme.auroraRed.withOpacity(0.40),
                      blurRadius: AuroraTheme.spacingL,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),

        // Meta line: CITY · JOB · EDU
        _MetaLine(
          cityName: cityName,
          job: job,
          education: education,
        ),
      ],
    );
  }
}

// ── Meta Line ─────────────────────────────────────────────────────────────────
class _MetaLine extends StatelessWidget {
  final String cityName;
  final String? job;
  final String? education;
  const _MetaLine({required this.cityName, this.job, this.education});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (cityName.isNotEmpty) parts.add(cityName.toUpperCase());
    if (job != null && job!.isNotEmpty) parts.add(job!.toUpperCase());
    if (education != null && education!.isNotEmpty) {
      parts.add(education!.toUpperCase());
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 3,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AuroraTheme.metaSeparator,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ));
      }
      spans.add(TextSpan(text: parts[i]));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontFamily: AuroraTheme.fontMono,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.76, // 0.16em @ 11px
        color: AuroraTheme.textMetaLine,
      ),
    );
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Content Section — bio, interests, prompts
// ─────────────────────────────────────────────────────────────────────────────
class _ContentSection extends StatelessWidget {
  final String? bio;
  final List<String> interests;
  final AsyncValue promptsAsync;
  // FIX #5: topPadding from parent (topPad + 56) clears fixed back button
  final double topPadding;

  const _ContentSection({
    this.bio,
    required this.interests,
    required this.promptsAsync,
    required this.topPadding,
  });

  String _questionLabel(String key) {
    const labels = {
      'favorite_restaurant': 'Favori Restoranım',
      'last_book': 'Son Okuduğum Kitap',
      'perfect_evening': 'Mükemmel Bir Akşam',
      'travel_dream': 'Hayalimdeki Seyahat',
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuroraTheme.bgDeep,
      child: Padding(
        // FIX #5: top = topPadding (safe from fixed back button)
        padding: EdgeInsets.fromLTRB(
          AuroraTheme.spacingXL,
          topPadding,
          AuroraTheme.spacingXL,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Bio — editorial pull-quote ────────────────────────────────
            if (bio != null && bio!.isNotEmpty) ...[
              _BioPullQuote(text: bio!),
              const SizedBox(height: AuroraTheme.spacingXXXL),
            ],

            // ── Interests ─────────────────────────────────────────────────
            if (interests.isNotEmpty) ...[
              const _SectionHeader(label: 'İlgi Alanları'),
              const SizedBox(height: AuroraTheme.spacingL),
              // FIX #7: pill height matches padding 9+font+9 ≈ 34px; ListView
              // height 38 gives small buffer. Pill padding: 9×16, font: 13.
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: interests.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AuroraTheme.spacingS),
                  itemBuilder: (_, i) => _InterestPill(
                    label: interests[i],
                    accent: i == 0,
                  ),
                ),
              ),
              const SizedBox(height: AuroraTheme.spacingXXXL),
            ],

            // ── Prompts ───────────────────────────────────────────────────
            promptsAsync.maybeWhen(
              data: (prompts) {
                final list = prompts as List;
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SectionHeader(label: 'İfadeler'),
                    const SizedBox(height: AuroraTheme.spacingL),
                    ...list.map((p) {
                      final map = p as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AuroraTheme.spacingM),
                        child: _PromptCard(
                          question: _questionLabel(
                              map['question_key'] as String),
                          answer: map['answer'] as String? ?? '',
                        ),
                      );
                    }),
                    const SizedBox(height: AuroraTheme.spacingM),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bio pull-quote — editorial style ──────────────────────────────────────────
class _BioPullQuote extends StatelessWidget {
  final String text;
  const _BioPullQuote({required this.text});

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
            const SizedBox(width: AuroraTheme.spacingL),
            Expanded(
              child: Text(
                '\u201C$text\u201D',
                style: TextStyle(
                  fontFamily: AuroraTheme.fontDisplay,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  height: 1.55,
                  letterSpacing: -0.09, // -0.005em @ 18px
                  color: AuroraTheme.textPullQuote,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Section Header — 40px gradient line + mono caps label ─────────────────────
// FIX #8: SizedBox(width:40) is explicit; Container(width:40) could be
// misinterpreted by certain layout engines on high-density devices.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.6,
            child: SizedBox(
              width: 40,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AuroraTheme.redBlueGradient,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          const SizedBox(width: AuroraTheme.spacingM),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AuroraTheme.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.98, // 0.18em @ 11px
              color: AuroraTheme.textSectionLabel,
            ),
          ),
        ],
      );
}

// ── Interest Pill — uses AuroraGlassPill (backdrop blur included) ─────────────
// FIX #7: padding: 9×16, fontSize: 13, weight: 500, radius: 100 (via GlassPill)
class _InterestPill extends StatelessWidget {
  final String label;
  final bool accent;
  const _InterestPill({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) => AuroraGlassPill(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, // mockup: .pill { padding: 9px 16px }
          vertical: 9,
        ),
        backgroundGradient: accent ? AuroraTheme.redBlueSoftGradient : null,
        borderColor: accent
            ? AuroraTheme.auroraRed.withOpacity(0.35)
            : AuroraTheme.glassBorder,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AuroraTheme.fontBody,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.065, // -0.005em @ 13px
            color: Colors.white.withOpacity(accent ? 1.0 : 0.85),
          ),
        ),
      );
}

// ── Prompt Card — uses AuroraGlassCard, neutral left bar ─────────────────────
class _PromptCard extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => AuroraGlassCard(
        radius: AuroraTheme.radiusInfoCard,
        padding: EdgeInsets.zero,
        blurRadius: 20,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar — neutral white
              Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AuroraTheme.glassBarNeutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        question.toUpperCase(),
                        style: TextStyle(
                          fontFamily: AuroraTheme.fontMono,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.4, // 0.14em @ 10px
                          color: AuroraTheme.textPromptLabel,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        answer,
                        style: TextStyle(
                          fontFamily: AuroraTheme.fontDisplay,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          fontSize: 22,
                          height: 1.3,
                          letterSpacing: -0.22, // -0.01em @ 22px
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Gradient CTA ──────────────────────────────────────────────────────────────
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
            gradient: AuroraTheme.redBlueGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AuroraTheme.auroraRed.withOpacity(0.28),
                blurRadius: AuroraTheme.spacingXXL,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AuroraTheme.auroraBlue.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AuroraTheme.fontBody,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.08,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

// ── Glass Icon Button ─────────────────────────────────────────────────────────
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
                border:
                    Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
}

// ── Favorite Button ───────────────────────────────────────────────────────────
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
                      : Colors.white.withOpacity(0.20),
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

// ── Action Sheet ──────────────────────────────────────────────────────────────
class _ActionSheet extends StatelessWidget {
  final String targetUserId;
  final String? targetName;
  const _ActionSheet({required this.targetUserId, this.targetName});

  Future<void> _block(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AuroraTheme.bgSoft,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Kullanıcıyı engelle',
          style: TextStyle(
              fontFamily: AuroraTheme.fontDisplay,
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: Colors.white),
        ),
        content: Text(
          'Bu kullanıcıyı engellemek istediğine emin misin?',
          style: TextStyle(
              fontFamily: AuroraTheme.fontBody,
              fontSize: 14,
              color: AuroraTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: TextStyle(
                    fontFamily: AuroraTheme.fontBody,
                    color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Engelle',
                style: TextStyle(
                    fontFamily: AuroraTheme.fontBody,
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
        content: Text(
          '${targetName ?? 'Kullanıcı'} engellendi',
          style: TextStyle(fontFamily: AuroraTheme.fontBody),
        ),
        backgroundColor: AuroraTheme.successGreen,
      ));
      ctx.pop();
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AuroraTheme.bgSoft.withOpacity(0.90),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                  top: BorderSide(color: AuroraTheme.glassBorder)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AuroraTheme.spacingM),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AuroraTheme.redBlueGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AuroraTheme.spacingS),
                  ListTile(
                    leading: const Icon(Icons.block,
                        color: AuroraTheme.auroraRed),
                    title: Text('Kullanıcıyı engelle',
                        style: TextStyle(
                            fontFamily: AuroraTheme.fontBody,
                            fontSize: 15,
                            color: Colors.white)),
                    onTap: () => _block(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.flag_outlined,
                        color: AuroraTheme.auroraGold),
                    title: Text('Rapor et',
                        style: TextStyle(
                            fontFamily: AuroraTheme.fontBody,
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
                    title: Text('İptal',
                        style: TextStyle(
                            fontFamily: AuroraTheme.fontBody,
                            fontSize: 15,
                            color: AuroraTheme.textSecondary)),
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: AuroraTheme.spacingL),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Full-screen Photo Viewer ──────────────────────────────────────────────────
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
                    errorWidget: (_, _, _) => const Icon(
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
