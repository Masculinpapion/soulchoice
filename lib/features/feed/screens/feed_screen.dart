import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invitation/create'),
        backgroundColor: AppColors.red,
        label: Text('+ Davet aç', style: AppTextStyles.labelLarge),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onCityTap;
  final VoidCallback onNotificationTap;

  const _Header({required this.onCityTap, required this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Row(
        children: [
          Text('SoulChoice', style: AppTextStyles.headingLarge),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCityTap,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              borderRadius: BorderRadius.circular(100),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text('Moskova', style: AppTextStyles.monoSmall.copyWith(color: AppColors.textSecondary)),
                  const Icon(Icons.expand_more, size: 14, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: onNotificationTap,
          ),
        ],
      ),
    );
  }
}

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
          color: AppColors.red,
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
            child: FilterChip(
              label: Text('${c.emoji} ${c.label}'),
              selected: isSelected,
              onSelected: (_) => onSelected(c),
              backgroundColor: AppColors.glassBg,
              selectedColor: AppColors.red.withOpacity(0.2),
              checkmarkColor: AppColors.red,
              side: BorderSide(color: isSelected ? AppColors.red : AppColors.glassBorder),
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? AppColors.red : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InvitationList extends ConsumerWidget {
  final InvitationFlowType flowType;
  final InvitationCategory? category;

  const _InvitationList({required this.flowType, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: replace with real provider
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InvitationCard(
          title: 'WHITE RABBIT',
          category: InvitationCategory.food,
          venueName: 'White Rabbit Restaurant',
          ownerName: 'Dmitri',
          ownerAge: 31,
          timeRemaining: Duration(hours: 18 - i * 3),
          applicationCount: 4 + i,
          onTap: () => context.push('/invitation/${i + 1}'),
        ),
      ),
    );
  }
}

class InvitationCard extends StatelessWidget {
  final String title;
  final InvitationCategory category;
  final String venueName;
  final String ownerName;
  final int ownerAge;
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
    required this.timeRemaining,
    required this.applicationCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background photo placeholder
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.red.withOpacity(0.3),
                      AppColors.blue.withOpacity(0.2),
                    ],
                  ),
                ),
              ),
              // Gradient overlay for readability
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgBlack.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text('${category.emoji} ${category.label}', style: AppTextStyles.monoSmall),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: AppTextStyles.feedCardTitle),
                    const SizedBox(height: 4),
                    Text(venueName, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('$ownerName, $ownerAge', style: AppTextStyles.labelMedium),
                        const Spacer(),
                        const Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('$applicationCount', style: AppTextStyles.mono),
                        const SizedBox(width: 12),
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${timeRemaining.inHours}s',
                          style: AppTextStyles.mono,
                        ),
                      ],
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
