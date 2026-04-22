import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

class ApplicantsScreen extends StatelessWidget {
  final String invitationId;
  const ApplicantsScreen({super.key, required this.invitationId});

  // Placeholder data — replace with real provider
  static const _applicants = [
    ('Anastasia', 26, true),
    ('Marina', 29, false),
    ('Elena', 24, true),
    ('Sofia', 31, true),
    ('Natasha', 27, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text('Başvuranlar', style: AppTextStyles.titleMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_applicants.length} kişi',
                style: AppTextStyles.mono,
              ),
            ),
          ),
        ],
      ),
      body: AmbientBackground(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _applicants.length,
          itemBuilder: (_, i) {
            final (name, age, verified) = _applicants[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('$name, $age', style: AppTextStyles.titleMedium),
                            if (verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.gold, size: 16),
                            ],
                          ]),
                          Text('Profili incele', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/invitation/$invitationId/decision');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Seç', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
