import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  static const _permissions = [
    (Icons.location_on_outlined, 'Konum', 'Yakınındaki davetleri görmek için'),
    (Icons.notifications_outlined, 'Bildirimler', 'Seçildiğinde ve yeni mesajlarda haber al'),
    (Icons.camera_alt_outlined, 'Kamera', 'Selfie doğrulaması için'),
  ];

  Future<void> _requestAll(BuildContext context) async {
    await [
      Permission.location,
      Permission.notification,
      Permission.camera,
    ].request();
    if (context.mounted) context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Son bir adım', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'SoulChoice\'un tam deneyimi için bu izinlere ihtiyacımız var',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),
                ..._permissions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(p.$1, color: AppColors.red, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.$2, style: AppTextStyles.labelLarge),
                                const SizedBox(height: 2),
                                Text(p.$3, style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ScButton(
                  label: 'İzinleri ver',
                  onPressed: () => _requestAll(context),
                ),
                const SizedBox(height: 12),
                ScButton(
                  label: 'Şimdi değil',
                  variant: ScButtonVariant.ghost,
                  onPressed: () => context.go('/feed'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
