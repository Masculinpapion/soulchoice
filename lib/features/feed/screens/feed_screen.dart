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
              _SanaOzel(
                selected: _selectedCategory,
                onSelected: (c) => setState(() {
                  _selectedCategory = _selectedCategory == c ? null : c;
                }),
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
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

    final invitations = async.asData?.value ?? [];
    if (invitations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                final storyLabel = (inv.venueName != null &&
                        inv.venueName!.isNotEmpty)
                    ? (inv.venueName!.length > 10
                        ? inv.venueName!.substring(0, 10)
                        : inv.venueName!)
                    : (inv.owner?.name ?? '—').split(' ').first;

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
                        errorWidget: (_, __, ___) => _AvatarFallback(),
                      )
                    : _AvatarFallback(),
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
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.glassBgMedium,
        child: const Icon(Icons.person,
            size: 24, color: AppColors.textTertiary),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sana Özel (mood / time-slot cards)
// ─────────────────────────────────────────────────────────────────────────────

class _MoodData {
  final String time;
  final String label;
  final String emoji;
  final InvitationCategory category;
  final List<Color> colors;
  const _MoodData(this.time, this.label, this.emoji, this.category, this.colors);
}

const _moodList = [
  _MoodData('12:00', 'Öğlen', '🍽', InvitationCategory.food,
      [Color(0xFF9D4EDD), Color(0xFFFF6B35)]),
  _MoodData('15:00', 'Kahve', '☕', InvitationCategory.coffee,
      [Color(0xFF0891B2), Color(0xFF155E75)]),
  _MoodData('19:00', 'Konser', '🎵', InvitationCategory.concert,
      [Color(0xFF7C3AED), Color(0xFFDB2777)]),
  _MoodData('21:00', 'Sinema', '🎬', InvitationCategory.cinema,
      [Color(0xFF312E81), Color(0xFF7C3AED)]),
  _MoodData('23:00', 'Gece', '🎨', InvitationCategory.culture,
      [Color(0xFF4C1D95), Color(0xFF1E1B4B)]),
];

class _SanaOzel extends StatelessWidget {
  final InvitationCategory? selected;
  final ValueChanged<InvitationCategory> onSelected;
  const _SanaOzel({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: const Text(
                  'SANA ÖZEL',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moodList.length,
            itemBuilder: (_, i) {
              final mood = _moodList[i];
              final isActive = selected == mood.category;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => onSelected(mood.category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 92,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: mood.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? Colors.white.withOpacity(0.6)
                            : Colors.white.withOpacity(0.12),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: mood.colors[0].withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mood.time,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            mood.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mood.label,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;

  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelMedium,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        tabs: const [
          Tab(text: 'Davetler'),
          Tab(text: 'İstekler'),
        ],
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
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                child: Text(
                  '${c.emoji} ${c.label}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 310,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Background photo ─────────────────────────────────────
              if (ownerPhotoUrl != null)
                CachedNetworkImage(
                  imageUrl: ownerPhotoUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => _CardFallbackGradient(),
                  errorWidget: (_, __, ___) => _CardFallbackGradient(),
                )
              else
                _CardFallbackGradient(),

              // ── 2. Top scrim ────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0xB0000000), Colors.transparent],
                  ),
                ),
              ),

              // ── 3. Bottom content scrim ─────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xF0000000), Colors.transparent],
                  ),
                ),
              ),

              // ── 4. Top-left: Owner avatar + name ────────────────────────
              Positioned(
                top: 16,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.glassBorderBright, width: 1.5),
                      ),
                      child: ClipOval(
                        child: ownerPhotoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: ownerPhotoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: AppColors.textTertiary),
                              )
                            : const Icon(Icons.person,
                                size: 20, color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$ownerName, $ownerAge',
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                        Text(
                          venueName.isNotEmpty
                              ? venueName
                              : category.label,
                          style: AppTextStyles.monoSmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 5. Top-right: Countdown timer pill ──────────────────────
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.glassBgStrong,
                        borderRadius: BorderRadius.circular(100),
                        border:
                            Border.all(color: AppColors.glassBorderBright),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.primaryGradient.createShader(b),
                            child: const Icon(Icons.timer_outlined,
                                size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatTimer(timeRemaining),
                            style: AppTextStyles.monoSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 6. Bottom content ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title.toUpperCase(),
                        style: AppTextStyles.feedCardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Event date
                      if (eventDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 11,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatEventDate(eventDate!),
                              style: AppTextStyles.monoSmall.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Overlapping applicant avatars + text
                          _ApplicantAvatars(
                            photoUrls: applicantPhotoUrls,
                            label: _applicantText(),
                            count: applicationCount,
                          ),
                          const Spacer(),
                          // CTA Button
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gradientStart
                                      .withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Gelmek isterim',
                              style: AppTextStyles.monoSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                          color: const Color(0xFF070B14), width: 2),
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
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
          ),
        ),
      );
}
