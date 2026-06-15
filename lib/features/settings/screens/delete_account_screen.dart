import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _isDeleting = false;

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke('delete-account');
      if (response.status != 200) {
        throw Exception((response.data as Map<String, dynamic>?)?['error'] ?? 'delete failed');
      }
      await client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.delete_account_success),
          ),
        );
        context.go('/splash');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.delete_account_error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context)!.delete_account_title, style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.delete_account_heading, style: AppTextStyles.headingLarge.copyWith(color: AppColors.error)),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.delete_account_body,
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Column(
                  children: [
                    _WarnItem(text: AppLocalizations.of(context)!.delete_account_warn_profile),
                    const SizedBox(height: 10),
                    _WarnItem(text: AppLocalizations.of(context)!.delete_account_warn_messages),
                    const SizedBox(height: 10),
                    _WarnItem(text: AppLocalizations.of(context)!.delete_account_warn_invitations),
                    const SizedBox(height: 10),
                    _WarnItem(text: AppLocalizations.of(context)!.delete_account_warn_phone),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                onTap: () => setState(() => _confirmed = !_confirmed),
                borderColor: _confirmed ? AppColors.error : AppColors.glassBorder,
                child: Row(
                  children: [
                    Checkbox(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      activeColor: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.delete_account_checkbox,
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Manrope', fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_confirmed)
                ScButton(
                  label: AppLocalizations.of(context)!.delete_account_btn_delete,
                  onPressed: _delete,
                  isLoading: _isDeleting,
                  icon: Icons.fingerprint,
                ),
              const SizedBox(height: 12),
              ScButton(
                label: AppLocalizations.of(context)!.delete_account_btn_cancel,
                variant: ScButtonVariant.secondary,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarnItem extends StatelessWidget {
  final String text;
  const _WarnItem({required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close, color: AppColors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      );
}

