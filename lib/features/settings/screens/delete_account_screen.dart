import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/session_expiry.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
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
        throw Exception(
          (response.data as Map<String, dynamic>?)?['error'] ?? 'delete failed',
        );
      }
      SessionExpiry.manualLogout = true;
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.delete_account_error),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.delete_account_title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AuroraTheme.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          top: false,
          // 24.07: İptal butonu sistem çubuğu/klavye altında kalıyordu
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
                  color: AuroraTheme.auroraRed.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AuroraTheme.auroraRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.delete_account_heading,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AuroraTheme.auroraRed,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.delete_account_body,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  color: AuroraTheme.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Column(
                  children: [
                    _WarnItem(
                      text: AppLocalizations.of(
                        context,
                      )!.delete_account_warn_profile,
                    ),
                    const SizedBox(height: 10),
                    _WarnItem(
                      text: AppLocalizations.of(
                        context,
                      )!.delete_account_warn_messages,
                    ),
                    const SizedBox(height: 10),
                    _WarnItem(
                      text: AppLocalizations.of(
                        context,
                      )!.delete_account_warn_invitations,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                onTap: () => setState(() => _confirmed = !_confirmed),
                borderColor: _confirmed
                    ? AuroraTheme.auroraRed
                    : AuroraTheme.glassBorder,
                child: Row(
                  children: [
                    Checkbox(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      activeColor: AuroraTheme.auroraRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.delete_account_checkbox,
                        style: const TextStyle(
                          color: AuroraTheme.textPrimary,
                          fontFamily: 'Manrope',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_confirmed)
                ScButton(
                  label: AppLocalizations.of(
                    context,
                  )!.delete_account_btn_delete,
                  onPressed: _delete,
                  isLoading: _isDeleting,
                  icon: Icons.delete_forever,
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
      const Icon(Icons.close, color: AuroraTheme.auroraRed, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            color: AuroraTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}
