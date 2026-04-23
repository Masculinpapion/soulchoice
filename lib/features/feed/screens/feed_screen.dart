import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      floatingActionButton: _GradientFab(
        onTap: () => context.push('/invitation/create'),
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
          _IconBtn(
            icon: Icons.person_outline,
            onTap: () {
              final uid =
                  Supabase.instance.client.auth.currentUser?.id;
              if (uid != null) context.push('/profile/$uid');
            },
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
      height: 96,
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
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
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
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () => context.push('/invitation/${inv.id}'),
                    child: _StoryAvatar(
                      photoUrl: inv.ownerPhotoUrl,
                      name: (inv.owner?.name ?? '—').split(' ').first,
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
  final String name;
  const _StoryAvatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
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
        const SizedBox(height: 4),
        Text(
          name,
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
// Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;

  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
        child: Text('Hata: $e',
            style: AppTextStyles.bodyMedium),
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
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('İlk daveti sen aç!',
                    style: AppTextStyles.mono),
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
    required this.onTap,
  });

  String _formatTimer(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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
              // ── 1. Background photo ──────────────────────────────────────
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

              // ── 2. Top scrim (readability for avatar/timer) ───────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0xB0000000), Colors.transparent],
                  ),
                ),
              ),

              // ── 3. Bottom content scrim ───────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xF0000000), Colors.transparent],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),

              // ── 4. Top-left: Avatar + name ────────────────────────────────
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
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.person,
                                        size: 20,
                                        color: AppColors.textTertiary),
                              )
                            : const Icon(Icons.person,
                                size: 20,
                                color: AppColors.textTertiary),
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
                          venueName.isNotEmpty ? venueName : category.label,
                          style: AppTextStyles.monoSmall.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 5. Top-right: Countdown timer pill ────────────────────────
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

              // ── 6. Bottom content ─────────────────────────────────────────
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Category chip
                          _InfoPill(
                            child: Text(
                              '${category.emoji}  ${category.label}',
                              style: AppTextStyles.monoSmall.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Application count
                          _InfoPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 12,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '$applicationCount',
                                  style: AppTextStyles.monoSmall.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
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

class _InfoPill extends StatelessWidget {
  final Widget child;
  const _InfoPill({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.glassBgStrong,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: child,
          ),
        ),
      );
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

// ─────────────────────────────────────────────────────────────────────────────
// Gradient FAB
// ─────────────────────────────────────────────────────────────────────────────

class _GradientFab extends StatelessWidget {
  final VoidCallback onTap;
  const _GradientFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.gradientStart.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Davet aç',
              style:
                  AppTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
