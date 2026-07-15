import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/session_expiry.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';

/// Askıya alınan / banlanan hesabın gördüğü tam ekran durum sayfası.
/// suspension_reason iç not olabildiği için EKRANDA GÖSTERİLMEZ — genel metin
/// + destek e-postası. Sunucu guard'ları zaten aksiyonları kesiyor; bu ekran
/// kullanıcının "app bozuk" sanmasını önler (Kullanıcı Kapısı §13.1/2).
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: const Icon(Icons.pause_circle_outline_rounded,
                      color: Colors.white, size: 64),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.suspended_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.suspended_body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    height: 1.6,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('mailto:support@soulchoice.app'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AuroraTheme.redBlueGradient,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      l10n.suspended_contact,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    SessionExpiry.manualLogout = true;
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/onboarding');
                  },
                  child: Text(
                    l10n.suspended_logout,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
