import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AuroraTheme.bgDeep,
        body: profileAsync.when(
          loading: () => AmbientBackground(
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
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
                  child: Text('Profil bulunamadı',
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
            final interests =
                (user['interests'] as List?)?.cast<String>() ?? [];
            final photos = photosAsync.asData?.value ?? [];

            final metaParts = [
              if (cityName.isNotEmpty) cityName,
              if (job != null && job.isNotEmpty) job,
              if (education != null && education.isNotEmpty) education,
            ].join(' · ');

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
              trailing = const SizedBox(width: 38);
            }

            final bottomPad = MediaQuery.of(context).padding.bottom +
                kBottomNavigationBarHeight +
                24;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero %45 ──────────────────────────────────────
                      _HeroSection(
                        photos: photos,
                        initialIndex: _photoIndex,
                        onPageChanged: (i) =>
                            setState(() => _photoIndex = i),
                        onBack: () => context.pop(),
                        trailing: trailing,
                      ),

                      const SizedBox(height: 12),

                      // ── Scroll İçerik ─────────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // İsim Kartı
                            _NameCard(
                              name: name,
                              age: age,
                              verified: verified,
                              metaParts: metaParts,
                            ),

                            // Bio
                            if (bio != null && bio.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _BioSection(bio: bio),
                            ],

                            // İlgi Alanları
                            if (interests.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const _V2SectionHeader(
                                  label: 'İLGİ ALANLARI'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: interests
                                    .asMap()
                                    .entries
                                    .map((e) => _InterestChip(
                                        label: e.value,
                                        colorIndex: e.key))
                                    .toList(),
                              ),
                            ],

                            // İfadeler
                            promptsAsync.maybeWhen(
                              data: (prompts) {
                                final list =
                                    (prompts as List)
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
                                    const SizedBox(height: 20),
                                    const _V2SectionHeader(
                                        label: 'İFADELER'),
                                    const SizedBox(height: 10),
                                    ...list.map((p) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _PromptCard(
                                            question: _questionLabel(
                                                p['question_key']
                                                    as String),
                                            answer:
                                                p['answer'] as String,
                                          ),
                                        )),
                                  ],
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 24),

                            // CTA
                            isOwnProfile
                                ? _OutlineCTA(
                                    label: 'Profili Düzenle',
                                    onTap: () =>
                                        context.push('/profile/setup'),
                                  )
                                : _AuroraCTA(
                                    label: 'Gelmek isterim',
                                    onTap: () => context.pop(),
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
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ActionSheet(targetUserId: targetUserId, targetName: null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Hero Section — %45 ekran, PageView.builder
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final Widget trailing;

  const _HeroSection({
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.trailing,
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.45;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // PageView.builder
          if (widget.photos.isNotEmpty)
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) {
                setState(() => _current = i);
                widget.onPageChanged(i);
              },
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.photos[i]['url'] as String,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorWidget: (_, __, ___) => _NoPhotoPlaceholder(),
              ),
            )
          else
            _NoPhotoPlaceholder(),

          // Üst gradient scrim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Alt gradient fade → bgDeep
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AuroraTheme.bgDeep,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top bar: geri | dots | trailing
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: widget.onBack,
                    ),
                    Expanded(
                      child: Center(
                        child: widget.photos.length > 1
                            ? _DotIndicator(
                                count: widget.photos.length,
                                current: _current,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    widget.trailing,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Dot Indicator
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
            width: isActive ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              gradient: isActive ? AuroraTheme.redBlueGradient : null,
              color: isActive ? null : Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(100),
            ),
          );
        }),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: V2 Section Header — yatay çizgi + mono label
// ─────────────────────────────────────────────────────────────────────────────
class _V2SectionHeader extends StatelessWidget {
  final String label;
  const _V2SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: AuroraTheme.redBlueGradient,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
              letterSpacing: 0.16,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Name Card — glass kart, isim + meta satır
// ─────────────────────────────────────────────────────────────────────────────
class _NameCard extends StatelessWidget {
  final String name;
  final int age;
  final bool verified;
  final String metaParts;

  const _NameCard({
    required this.name,
    required this.age,
    required this.verified,
    required this.metaParts,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '$name, $age',
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AuroraTheme.redBlueGradient,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AuroraTheme.auroraRed.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 13),
                      ),
                    ],
                  ],
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    metaParts,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Bio Section — sol gradient çizgi + italic metin
// ─────────────────────────────────────────────────────────────────────────────
class _BioSection extends StatelessWidget {
  final String bio;
  const _BioSection({required this.bio});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: AuroraTheme.redBlueGradient,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bio,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Prompt Card — glass kart, sol nötr çizgi + soru/cevap
// ─────────────────────────────────────────────────────────────────────────────
class _PromptCard extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            padding: const EdgeInsets.all(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.38),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          answer,
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mevcut widget'lar — değiştirilmedi
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoHero extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final String name;
  final int age;
  final bool verified;
  final String cityName;
  final String? job;

  const _PhotoHero({
    required this.photos,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.name,
    required this.age,
    required this.verified,
    required this.cityName,
    this.job,
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
          if (url != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => _NoPhotoPlaceholder(),
              ),
            )
          else
            _NoPhotoPlaceholder(),
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.92),
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.85],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontStyle: FontStyle.italic,
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(blurRadius: 20, color: Colors.black87),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '${widget.age}',
                          style: TextStyle(
                            fontFamily: 'Fraunces',
                            fontStyle: FontStyle.italic,
                            fontSize: 26,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.75),
                            height: 1.0,
                          ),
                        ),
                      ),
                      if (widget.verified) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AuroraTheme.auroraBlue,
                              boxShadow: [
                                BoxShadow(
                                  color: AuroraTheme.auroraBlue.withOpacity(0.6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (widget.cityName.isNotEmpty)
                        _OverlayPill(
                          icon: Icons.location_on_outlined,
                          text: widget.cityName,
                        ),
                      if (widget.job != null && widget.job!.isNotEmpty)
                        _OverlayPill(
                          icon: Icons.work_outline_rounded,
                          text: widget.job!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 12, 56, 0),
                  child: Row(
                    children: List.generate(
                      widget.photos.length,
                      (i) {
                        final isActive = i == widget.currentIndex;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < widget.photos.length - 1 ? 4 : 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? AuroraTheme.redBlueGradient
                                    : null,
                                color: isActive
                                    ? null
                                    : Colors.white.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
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

class _OverlayPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _OverlayPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: AuroraTheme.auroraRed),
                const SizedBox(width: 5),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ContentSection extends StatelessWidget {
  final String? bio;
  final String? job;
  final String? education;
  final List<String> interests;
  final List<Map<String, dynamic>> photos;
  final AsyncValue promptsAsync;
  final bool isOwnProfile;
  final int currentPhotoIndex;
  final ValueChanged<int> onPhotoTap;

  const _ContentSection({
    this.bio,
    this.job,
    this.education,
    required this.interests,
    required this.photos,
    required this.promptsAsync,
    required this.isOwnProfile,
    required this.currentPhotoIndex,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: AuroraTheme.bgDeep)),
          Positioned(
            top: -60, left: -80, width: 320, height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AuroraTheme.auroraRed.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200, right: -60, width: 280, height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AuroraTheme.auroraBlue.withOpacity(0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 4),
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: AuroraTheme.redBlueGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (education != null && education!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MetaPillRow(education: education, job: null),
                ),
              ],
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GlassInfoCard(
                    label: 'HAKKIMDA',
                    accentColor: AuroraTheme.auroraRed,
                    child: Text(
                      '"$bio"',
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
              if (photos.length > 1) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _SectionHeader(label: 'FOTOĞRAFLAR'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      final isActive = i == currentPhotoIndex;
                      return GestureDetector(
                        onTap: () => onPhotoTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? AuroraTheme.auroraRed.withOpacity(0.70)
                                  : Colors.white.withOpacity(0.10),
                              width: isActive ? 2 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AuroraTheme.auroraRed
                                          .withOpacity(0.30),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: photos[i]['url'] as String,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorWidget: (_, __, ___) => Container(
                                color: AuroraTheme.glassBg,
                                child: const Icon(Icons.person_outline,
                                    color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(label: 'İLGİ ALANLARI'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests
                            .asMap()
                            .entries
                            .map((e) => _InterestChip(
                                label: e.value, colorIndex: e.key))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              promptsAsync.maybeWhen(
                data: (prompts) {
                  if ((prompts as List).isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(label: 'İFADELER'),
                        const SizedBox(height: 12),
                        ...prompts.asMap().entries.map((e) {
                          final p = e.value as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GlassInfoCard(
                              label: _questionLabel(
                                  p['question_key'] as String),
                              accentColor: e.key.isEven
                                  ? AuroraTheme.auroraViolet
                                  : AuroraTheme.auroraBlue,
                              child: Text(
                                p['answer'] as String? ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 17,
                                  color: Colors.white,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
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
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AuroraTheme.redBlueGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(label, style: AuroraTheme.monoLabel),
        ],
      );
}

class _MetaPillRow extends StatelessWidget {
  final String? job;
  final String? education;
  const _MetaPillRow({this.job, this.education});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (job != null && job!.isNotEmpty)
            _MetaPill(icon: Icons.work_outline_rounded, text: job!),
          if (education != null && education!.isNotEmpty)
            _MetaPill(icon: Icons.school_outlined, text: education!),
        ],
      );
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            constraints: const BoxConstraints(maxWidth: 160),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: AuroraTheme.auroraRed),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GlassInfoCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Color accentColor;
  const _GlassInfoCard({
    required this.label,
    required this.child,
    this.accentColor = AuroraTheme.auroraRed,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accentColor,
                          accentColor.withOpacity(0.20),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: AuroraTheme.monoLabel.copyWith(
                              color: accentColor.withOpacity(0.80),
                            ),
                          ),
                          const SizedBox(height: 8),
                          child,
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

class _InterestChip extends StatelessWidget {
  final String label;
  final int colorIndex;
  const _InterestChip({required this.label, required this.colorIndex});

  static const _colors = [
    AuroraTheme.auroraRed,
    AuroraTheme.auroraBlue,
    AuroraTheme.auroraViolet,
    AuroraTheme.auroraGold,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[colorIndex % _colors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.32)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }
}

class _AuroraCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AuroraCTA({required this.label, required this.onTap});

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
                color: AuroraTheme.auroraRed.withOpacity(0.40),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
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
            gradient: AuroraTheme.redBlueGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AuroraTheme.auroraRed.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.edit_outlined, color: Colors.white, size: 17),
                SizedBox(width: 8),
                Text(
                  'Profili Düzenle',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.40),
                border:
                    Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
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
      return const SizedBox(width: 38, height: 38);
    }
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _toggle,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFavorite!
                    ? AuroraTheme.auroraRed.withOpacity(0.20)
                    : Colors.black.withOpacity(0.40),
                border: Border.all(
                  color: _isFavorite!
                      ? AuroraTheme.auroraRed.withOpacity(0.6)
                      : Colors.white.withOpacity(0.18),
                ),
              ),
              child: Icon(
                _isFavorite!
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _isFavorite!
                    ? AuroraTheme.auroraRed
                    : Colors.white.withOpacity(0.7),
                size: 19,
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
    Navigator.pop(ctx);
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kullanıcıyı engelle',
          style: TextStyle(
              fontFamily: 'Fraunces',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: Colors.white),
        ),
        content: Text(
          'Bu kullanıcıyı engellemek istediğine emin misin?',
          style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: AuroraTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Engelle',
                style: TextStyle(
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
        content:
            Text('${targetName ?? 'Kullanıcı'} engellendi'),
        backgroundColor: const Color(0xFF10B981),
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
              color: const Color(0xFF0D0D12).withOpacity(0.90),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: AuroraTheme.glassBorder),
              ),
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
                    title: const Text('Kullanıcıyı engelle',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            color: Colors.white)),
                    onTap: () => _block(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.flag_outlined,
                        color: AuroraTheme.auroraGold),
                    title: const Text('Rapor et',
                        style: TextStyle(
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
                    title: Text('İptal',
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
