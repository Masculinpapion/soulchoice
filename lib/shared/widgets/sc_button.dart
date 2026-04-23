import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum ScButtonVariant { primary, secondary, ghost }

/// Premium gradient button system.
class ScButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ScButtonVariant variant;
  final IconData? icon;

  const ScButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = ScButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    final content = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.textPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
              ),
            ],
          );

    switch (variant) {
      case ScButtonVariant.primary:
        final isDisabled = onPressed == null && !isLoading;
        return Opacity(
          opacity: isDisabled ? 0.45 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.gradientStart.withOpacity(0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: isLoading ? null : onPressed,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withOpacity(0.08),
                highlightColor: Colors.white.withOpacity(0.04),
                child: Container(
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ),
          ),
        );

      case ScButtonVariant.secondary:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorderBright, width: 1),
            color: AppColors.glassBg,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(16),
              splashColor: AppColors.red.withOpacity(0.06),
              child: Container(
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        );

      case ScButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
    }
  }
}
