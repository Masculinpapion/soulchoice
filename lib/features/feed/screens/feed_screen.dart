import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/invitations_provider.dart';

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
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                onCityTap: () {},
                onNotificationTap: () {},
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

class _Header extends StatelessWidget {
  final VoidCallback onCityTap;
  final VoidCallback onNotificationTap;

  const _Header({required this.onCityTap, required this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: Text(
              'SoulChoice',
              style: AppTextStyles.headingLarge.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          _GlassChip(
            onTap: onCityTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 13, color: AppColors.red),
                const SizedBox(width: 4),
                Text('Moskova',
                    style: AppTextStyles.monoSmall
                        .copyWith(color: AppColors.textSecondary)),
                const Icon(Icons.expand_more,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.notifications_outlined,
            onTap: onNotificationTap,
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassChip({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: AppColors.textPrimary, size: 22),
        onPressed: onTap,
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

    // Sadece fotoğrafı olan davetler story'de görünsün
    final invitations = (async.asData?.value ?? [])
        .where((inv) => inv.ownerPhotoUrl != null)
        .toList();
    if (invitations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Aktif Davetler',
                    style: AppTextStyles.monoSmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.gradientStart,
                        AppColors.gradientEnd
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '24 saat',
                    style: AppTextStyles.monoSmall
                        .copyWith(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
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
                final isLive = DateTime.now()
                        .difference(inv.createdAt)
                        .inHours <
                    1;
                // Her zaman isim göster
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
                        colors: [Color(0xFFEF4444), Color(0xFFFF6D00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _AvatarFallback(name: label),
                      )
                    : _AvatarFallback(name: label),
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
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 8,
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
          style: AppTextStyles.monoSmall.copyWith(fontSize: 10),
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
        : raw.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFFBE185D), Color(0xFFD4AF37)],
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
// Tab Bar — hap (pill) toggle, splash logo stilinde
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
          // ── Kırmızı hap — Davetler ────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(0),
              child: _PillButton(
                label: 'Davetler',
                color: AppColors.primaryRed,
                active: isInvite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Mavi hap — İstekler ───────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(1),
              child: _PillButton(
                label: 'İstekler',
                color: AppColors.primaryBlue,
                active: !isInvite,
                glass: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final bool glass;

  const _PillButton({
    required this.label,
    required this.color,
    required this.active,
    this.glass = false,
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
                  spreadRadius: 0,
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
            // ── Silindirik gövde rengi (splash'taki 3D hap efekti) ──────────
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
            // ── Alt karartma ─────────────────────────────────────────────────
            if (active)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(glass ? 0.16 : 0.28),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            // ── Üst parlaklık şeridi ─────────────────────────────────────────
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
            // ── Glass gövde parlaklığı (mavi hap) ───────────────────────────
            if (active && glass)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.14),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            // ── Inactive border ──────────────────────────────────────────────
            if (!active)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: color.withOpacity(0.25),
                    width: 1,
                  ),
                ),
              ),
            // ── Label ────────────────────────────────────────────────────────
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white
                      : color.withOpacity(0.55),
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
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  color: isSelected ? null : AppColors.glassBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 13, height: 1.2)),
                    const SizedBox(width: 5),
                    Text(
                      c.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.2,
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

  const _InvitationList({required this.flowType, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = InvitationFilter(flowType: flowType, category: category);
    final async = ref.watch(invitationsProvider(filter));

    return async.when(
      loading: () => Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e', style: AppTextStyles.bodyMedium),
      ),
      data: (invitations) {
        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.explore_outlined,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 16),
                Text('Henüz davet yok',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('İlk daveti sen aç!', style: AppTextStyles.mono),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.gradientStart,
          backgroundColor: AppColors.glassBgMedium,
          onRefresh: () =>
              ref.refresh(invitationsProvider(filter).future),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: invitations.length,
            itemBuilder: (_, i) {
              final inv = invitations[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invitation Card  (cinematic, full-bleed)
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

  String _formatEventDate(DateTime dt) {
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    final day = days[dt.weekday - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $hour:$minute';
  }

  String _applicantText() {
    if (applicationCount == 0) return 'Henüz başvuran yok, ilk sen ol';
    if (applicationCount == 1) return '1 kişi ilgileniyor';
    return '$applicationCount kişi ilgileniyor';
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = flowType == InvitationFlowType.invite
        ? AppColors.primaryRed
        : AppColors.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(45),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45),
          child: SizedBox(
            height: 430,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Tam boy dikey portre fotoğraf ─────────────────────
                if (ownerPhotoUrl != null)
                  CachedNetworkImage(
                    imageUrl: ownerPhotoUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (_, __, ___) => _CardFallbackGradient(
                        ownerName: ownerName, category: category),
                  )
                else
                  _CardFallbackGradient(ownerName: ownerName, category: category),

              // ── 2. Üst hafif scrim ──────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment(0, 0.0),
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),

              // ── 3. Alt glassmorphism panel ──────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(45)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.60),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                              color: Colors.white.withOpacity(0.10),
                              width: 0.8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Başlık — tek satır, kompakt
                          Text(
                            title.toUpperCase(),
                            style: AppTextStyles.feedCardTitle.copyWith(
                              fontSize: 20,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Alt satır: geri sayım + başvuranlar + CTA
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Geri sayım pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: timeRemaining.inHours < 2
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xCCFF6D00),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimer(timeRemaining),
                                      style: const TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (applicationCount > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.group_outlined,
                                    size: 12,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  '$applicationCount',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // CTA
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: flowType == InvitationFlowType.invite
                                      ? AppColors.inviteGradient
                                      : AppColors.requestGradient,
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (flowType == InvitationFlowType.invite
                                              ? AppColors.primaryRed
                                              : AppColors.primaryBlue)
                                          .withOpacity(0.38),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  flowType == InvitationFlowType.invite
                                      ? 'Gelmek isterim'
                                      : 'Katılmak istiyorum',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 4. Üst glass pill: avatar + isim + yaş ──────────────────
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 0.8),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.30),
                                  width: 1.5),
                            ),
                            child: ClipOval(
                              child: ownerPhotoUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: ownerPhotoUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _AvatarFallback(name: ownerName),
                                    )
                                  : _AvatarFallback(name: ownerName),
                            ),
                          ),
                          const SizedBox(width: 9),
                          // İsim + venue/kategori
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$ownerName, $ownerAge',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  venueName.isNotEmpty
                                      ? venueName
                                      : category.label,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 9,
                                    color: Colors.white.withOpacity(0.60),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Kategori emoji badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              category.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
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
// Applicant Avatars (overlapping)
// ─────────────────────────────────────────────────────────────────────────────

class _ApplicantAvatars extends StatelessWidget {
  final List<String> photoUrls;
  final String label;
  final int count;
  const _ApplicantAvatars(
      {required this.photoUrls, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 9.0;
    final urls = photoUrls.take(4).toList();
    final stackWidth = urls.isEmpty
        ? 0.0
        : size + (urls.length - 1) * (size - overlap);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (urls.isNotEmpty)
          SizedBox(
            width: stackWidth,
            height: size,
            child: Stack(
              children: List.generate(urls.length, (i) {
                return Positioned(
                  left: i * (size - overlap),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.bgBlack, width: 2),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: urls[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.glassBgMedium,
                          child: const Icon(Icons.person,
                              size: 14,
                              color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        SizedBox(width: urls.isEmpty ? 0 : 6),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.monoSmall.copyWith(
              color: count == 0
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


class _CardFallbackGradient extends StatelessWidget {
  final String ownerName;
  final InvitationCategory category;
  const _CardFallbackGradient({this.ownerName = '', required this.category});

  @override
  Widget build(BuildContext context) {
    final raw = ownerName.trim();
    final initials = raw.isEmpty
        ? '✦'
        : raw.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D0B3A), Color(0xFF1A0812), Color(0xFF070B1A)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            category.emoji,
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 28),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6B21A8), Color(0xFFBE185D), Color(0xFFE63946)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBE185D).withOpacity(0.50),
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
