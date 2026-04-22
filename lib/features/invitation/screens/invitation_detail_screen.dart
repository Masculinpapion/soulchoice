import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

class InvitationDetailScreen extends ConsumerWidget {
  final String invitationId;
  const InvitationDetailScreen({super.key, required this.invitationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: load invitation from provider
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: AppColors.bgBlack,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.red.withOpacity(0.3), AppColors.blue.withOpacity(0.2)],
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xDD0A0A0B)],
                              stops: [0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: Text('WHITE RABBIT', style: AppTextStyles.feedCardTitle.copyWith(fontSize: 28)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          _InfoChip(icon: Icons.restaurant, label: 'Yemek'),
                          const SizedBox(width: 8),
                          _InfoChip(icon: Icons.timer_outlined, label: '18 saat kaldı'),
                          const SizedBox(width: 8),
                          _InfoChip(icon: Icons.people_outline, label: '7 başvuru'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Etkinlik', style: AppTextStyles.monoSmall),
                            const SizedBox(height: 6),
                            Text(
                              'White Rabbit\'te akşam yemeği, +1 arıyorum. Hesap benden.',
                              style: AppTextStyles.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Yer & Zaman', style: AppTextStyles.monoSmall),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text('White Rabbit, Moskova', style: AppTextStyles.bodyMedium),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text('Bugün 20:00', style: AppTextStyles.bodyMedium),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Davet sahibi', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 10),
                      GlassCard(
                        onTap: () => context.push('/profile/user_1'),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.glassBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('Dmitri, 31', style: AppTextStyles.titleMedium),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.gold, size: 16),
                                ]),
                                Text('Moskova', style: AppTextStyles.bodyMedium),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.bgBlack, Colors.transparent],
                  ),
                ),
                child: ScButton(
                  label: 'Gelmek isterim',
                  onPressed: () {
                    // TODO: submit application
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Başvurunuz gönderildi!')),
                    );
                    context.pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.monoSmall),
          ],
        ),
      );
}
