import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.primaryGradient.createShader(b),
                      child: Text(
                        'Keşfet',
                        style: AppTextStyles.headingLarge
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: const Icon(Icons.explore_outlined,
                    color: Colors.white, size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                'Yakında',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Yeni insanları keşfet, şehre göre filtrele.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
