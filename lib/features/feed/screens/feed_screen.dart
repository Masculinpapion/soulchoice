import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/invitations_provider.dart';
import '../../notifications/providers/notifications_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  InvitationCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                onCityTap: () {},
                onNotificationTap: () => context.push('/notifications'),
              ),
              _StoryBar(),
              _TabBar(controller: _tabController),
              _CategoryChips(
                selected: _selectedCategory,
                onSelected: (c) => setState(() {
                  _selectedCategory = _selectedCategory == c ? null : c;
                }),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _InvitationList(
                      flowType: InvitationFlowType.invite,
                      category: _selectedCategory,
                    ),
                    _InvitationList(
                      flowType: InvitationFlowType.request,
                      category: _selectedCategory,
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

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final VoidCallback onCityTap;
  final VoidCallback onNotificationTap;

  const _Header({required this.onCityTap, required this.onNotificationTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Row(
        children: [
          // Logo — gradient shimmer
          ShaderMask(
            shaderCallback: (bounds) =>
                AuroraTheme.redBlueGradient.createShader(bounds),
            child: const Text(
              'SoulChoice',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // City pill
          _GlassPill(
            onTap: onCityTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on,
                    size: 13, color: AuroraTheme.auroraRed),
                const SizedBox(width: 4),
                Text('Moskova',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AuroraTheme.textSecondary,
                    )),
                Icon(Icons.expand_more,
                    size: 14, color: AuroraTheme.textMuted),
              ],
            ),
          ),
          const Spacer(),
          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GlassPill(
                onTap: onNotificationTap,
                child: Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 20),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AuroraTheme.glassBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AuroraTheme.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Story Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StoryBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = InvitationFilter(flowType: InvitationFlowType.invite);
    final async = ref.watch(invitationsProvider(filter));

    final seen = <String>{};
    final invitations = (async.asData?.value ?? [])
        .where((inv) {
          if (inv.ownerPhotoUrl == null) return false;
          final ownerId = inv.owner?.id ?? '';
          if (seen.contains(ownerId)) return false;
          seen.add(ownerId);
          return true;
        })
        .toList();
    if (invitations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'AKTİF ŞİMDİ  ·  24 SAAT',
              style: AuroraTheme.monoLabel,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: invitations.take(10).length,
              itemBuilder: (_, i) {
                final inv = invitations[i];
                final isLive =
                    DateTime.now().difference(inv.createdAt).inHours < 1;
                final ownerName = inv.owner?.name ?? '—';
                final storyLabel = ownerName.split(' ').first;

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () => context.push('/invitation/${inv.id}'),
                    child: _StoryAvatar(
                      photoUrl: inv.ownerPhotoUrl,
                      label: storyLabel,
                      isLive: isLive,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String? photoUrl;
  final String label;
  final bool isLive;
  const _StoryAvatar(
      {required this.photoUrl, required this.label, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: isLive
                    ? const LinearGradient(
                        colors: [AuroraTheme.auroraRed, AuroraTheme.auroraViolet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          AuroraTheme.auroraRed,
                          AuroraTheme.auroraViolet,
                          AuroraTheme.auroraBlue,
                          AuroraTheme.auroraRed,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AuroraTheme.bgDeep, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _AvatarFallback(name: label),
                        )
                      : _AvatarFallback(name: label),
                ),
              ),
            ),
            if (isLive)
              Positioned(
                bottom: -2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AuroraTheme.auroraRed,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AuroraTheme.auroraRed.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
            color: AuroraTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({this.name = ''});

  @override
  Widget build(BuildContext context) {
    final raw = name.trim();
    final initials = raw.isEmpty
        ? '✦'
        : raw
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuroraTheme.auroraViolet,
            AuroraTheme.auroraRed,
            AuroraTheme.auroraBlue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Bar — Aurora pill toggle
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatefulWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInvite = widget.controller.index == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(0),
              child: _AuroraPillTab(
                label: 'Davetler',
                color: AuroraTheme.auroraRed,
                active: isInvite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(1),
              child: _AuroraPillTab(
                label: 'İstekler',
                color: AuroraTheme.auroraBlue,
                active: !isInvite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraPillTab extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _AuroraPillTab({
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    const h = 46.0;
    const radius = 23.0;
    final dark = Color.lerp(color, Colors.black, 0.40)!;
    final darkEdge = Color.lerp(color, Colors.black, 0.26)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.50),
                  blurRadius: 22,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [dark, color, color, darkEdge],
                        stops: const [0.0, 0.28, 0.65, 1.0],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.04),
                          Colors.white.withOpacity(0.08),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
            ),
            if (active)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            if (active)
              Positioned(
                top: 0,
                left: 10,
                right: 10,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            if (!active)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: color.withOpacity(0.30),
                    width: 1,
                  ),
                ),
              ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      active ? Colors.white : color.withOpacity(0.55),
                  letterSpacing: 0.5,
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
// Category Chips
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final InvitationCategory? selected;
  final ValueChanged<InvitationCategory> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        children: InvitationCategory.values.map((c) {
          final isSelected = selected == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            AuroraTheme.auroraRed,
                            AuroraTheme.auroraBlue
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isSelected ? null : AuroraTheme.glassBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AuroraTheme.glassBorder,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AuroraTheme.auroraRed.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.emoji,
                        style:
                            const TextStyle(fontSize: 13, height: 1.2)),
                    const SizedBox(width: 5),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                        color: isSelected
                            ? Colors.white
                            : AuroraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invitation List
// ─────────────────────────────────────────────────────────────────────────────

class _InvitationList extends ConsumerWidget {
  final InvitationFlowType flowType;
  final InvitationCategory? category;

  const _InvitationList(
      {required this.flowType, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter =
        InvitationFilter(flowType: flowType, category: category);
    final async = ref.watch(invitationsProvider(filter));

    return async.when(
      loading: () => Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: TextStyle(
                color: AuroraTheme.textSecondary,
                fontFamily: 'Manrope')),
      ),
      data: (invitations) {
        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: const Icon(Icons.explore_outlined,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz davet yok',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'İlk daveti sen aç!',
                  style: AuroraTheme.monoLabel,
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text('BUGÜNÜN DAVETLERİ', style: AuroraTheme.monoLabel),
                  const SizedBox(width: 6),
                  ShaderMask(
                    shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(b),
                    child: const Text('· KAYDIRDIR →',
                        style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            SizedBox(
          height: 496,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: invitations.length,
            itemBuilder: (_, i) {
              final inv = invitations[i];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: InvitationCard(
                  title: inv.title,
                  category: inv.category,
                  venueName: inv.venueName ?? '',
                  ownerName: inv.owner?.name ?? '—',
                  ownerAge: inv.owner?.age ?? 0,
                  ownerPhotoUrl: inv.ownerPhotoUrl,
                  timeRemaining: inv.timeRemaining,
                  applicationCount: inv.applicationCount ?? 0,
                  applicantPhotoUrls: inv.applicantPhotoUrls,
                  eventDate: inv.eventDate,
                  flowType: flowType,
                  onTap: () => context.push('/invitation/${inv.id}'),
                ),
              );
            },
          ),
        ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invitation Card — Aurora glass, cinematic full-bleed
// ─────────────────────────────────────────────────────────────────────────────

class InvitationCard extends StatelessWidget {
  final String title;
  final InvitationCategory category;
  final String venueName;
  final String ownerName;
  final int ownerAge;
  final String? ownerPhotoUrl;
  final Duration timeRemaining;
  final int applicationCount;
  final List<String> applicantPhotoUrls;
  final DateTime? eventDate;
  final VoidCallback onTap;
  final InvitationFlowType flowType;

  const InvitationCard({
    super.key,
    required this.title,
    required this.category,
    required this.venueName,
    required this.ownerName,
    required this.ownerAge,
    this.ownerPhotoUrl,
    required this.timeRemaining,
    required this.applicationCount,
    this.applicantPhotoUrls = const [],
    this.eventDate,
    required this.onTap,
    this.flowType = InvitationFlowType.invite,
  });

  String _formatTimer(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// "SALI · 20:30 · VENUE" formatında mono caps meta satırı
  String _metaLabel(DateTime dt) {
    const days = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'];
    final day = days[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final venue = venueName.isNotEmpty ? venueName.toUpperCase() : category.label.toUpperCase();
    return '$day · $h:$m · $venue';
  }

  @override
  Widget build(BuildContext context) {
    final isInviteFlow = flowType == InvitationFlowType.invite;
    final glowColor = isInviteFlow ? AuroraTheme.auroraRed : AuroraTheme.auroraBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: glowColor.withOpacity(0.20),
              blurRadius: 40,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Arka plan fotoğrafı — tam kapak, yüz üstte
              if (ownerPhotoUrl != null)
                CachedNetworkImage(
                  imageUrl: ownerPhotoUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => _CardFallbackGradient(ownerName: ownerName, category: category),
                  errorWidget: (_, __, ___) => _CardFallbackGradient(ownerName: ownerName, category: category),
                )
              else
                _CardFallbackGradient(ownerName: ownerName, category: category),

              // 2. Gradient overlay — sadece alt %45, yüzü kapatmaz
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.40),
                        Colors.black.withOpacity(0.96),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Üst glass pill — avatar + isim/yaş + kategori emoji
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
                            ),
                            child: ClipOval(
                              child: ownerPhotoUrl != null
                                  ? CachedNetworkImage(imageUrl: ownerPhotoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _AvatarFallback(name: ownerName))
                                  : _AvatarFallback(name: ownerName),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$ownerName, $ownerAge',
                                  style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                Text(
                                  venueName.isNotEmpty ? venueName : category.label,
                                  style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, color: Colors.white.withOpacity(0.60)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                            child: Text(category.emoji, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Alt içerik — timer + meta + başlık + full-width CTA
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: timeRemaining.inHours < 2 ? AuroraTheme.auroraRed : const Color(0xCCFF6D00),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: timeRemaining.inHours < 2
                            ? [BoxShadow(color: AuroraTheme.auroraRed.withOpacity(0.5), blurRadius: 12)]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                          const SizedBox(width: 4),
                          Text(_formatTimer(timeRemaining), style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mono caps meta: "SALI · 20:30 · SMOLENSKAYA"
                    if (eventDate != null)
                      Text(
                        _metaLabel(eventDate!),
                        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 1.2),
                      ),
                    const SizedBox(height: 5),
                    // Fraunces italic başlık
                    Text(
                      title,
                      style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Full-width gradient CTA
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isInviteFlow
                                ? [AuroraTheme.auroraRed, AuroraTheme.auroraBlue]
                                : [AuroraTheme.auroraBlue, AuroraTheme.auroraRed],
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [BoxShadow(color: glowColor.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isInviteFlow ? 'Gelmek isterim' : 'Katılmak istiyorum',
                          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                        ),
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

class _CardFallbackGradient extends StatelessWidget {
  final String ownerName;
  final InvitationCategory category;
  const _CardFallbackGradient(
      {this.ownerName = '', required this.category});

  @override
  Widget build(BuildContext context) {
    final raw = ownerName.trim();
    final initials = raw.isEmpty
        ? '✦'
        : raw
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0510),
            Color(0xFF0A0B1A),
            AuroraTheme.bgDeep
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 28),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  AuroraTheme.auroraViolet,
                  AuroraTheme.auroraRed,
                  AuroraTheme.auroraBlue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraTheme.auroraRed.withOpacity(0.45),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
