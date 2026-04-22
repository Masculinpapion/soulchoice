import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

class ProfileViewScreen extends ConsumerWidget {
  final String userId;
  const ProfileViewScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: load user from provider
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              backgroundColor: AppColors.bgBlack,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showReportSheet(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppColors.glassBg),
                    // TODO: photo carousel
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text('Adı, 28', style: AppTextStyles.titleLarge),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: AppColors.gold, size: 18),
                                ],
                              ),
                              Text('Moskova', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  GlassCard(
                    child: Text('Bio placeholder...', style: AppTextStyles.bodyLarge),
                  ),
                  const SizedBox(height: 16),
                  Text('İlgi Alanları', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Müzik', 'Seyahat', 'Yemek'].map((i) =>
                      Chip(
                        label: Text(i, style: AppTextStyles.labelMedium),
                        backgroundColor: AppColors.glassBg,
                        side: const BorderSide(color: AppColors.glassBorder),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Sorular', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 10),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Favori restoranım...', style: AppTextStyles.monoSmall.copyWith(color: AppColors.textTertiary)),
                        const SizedBox(height: 4),
                        Text('Placeholder cevap', style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111114),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.error),
            title: Text('Şikayet et', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: AppColors.textSecondary),
            title: Text('Engelle', style: AppTextStyles.bodyLarge),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
