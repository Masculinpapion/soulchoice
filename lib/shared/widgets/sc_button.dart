import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum ScButtonVariant { primary, secondary, ghost }

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
              strokeWidth: 2,
              color: AppColors.textPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: _textColor),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppTextStyles.labelLarge.copyWith(color: _textColor)),
            ],
          );

    switch (variant) {
      case ScButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: content,
        );
      case ScButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.glassBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: content,
        );
      case ScButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
    }
  }

  Color get _textColor {
    switch (variant) {
      case ScButtonVariant.primary:
        return AppColors.textPrimary;
      case ScButtonVariant.secondary:
        return AppColors.textPrimary;
      case ScButtonVariant.ghost:
        return AppColors.textSecondary;
    }
  }
}
