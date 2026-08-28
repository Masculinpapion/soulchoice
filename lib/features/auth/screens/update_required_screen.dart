import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

/// min_supported_build kapısının tam ekran "güncelleme gerekli" sayfası.
/// Geri yolu bilinçli yok — eski sürüm sunucu tarafından desteklenmiyor.
/// Buton önce market:// dener (cihaz hangi mağazayı tanıyorsa o açılır:
/// GMS'de Play, GMS'siz RuStore kitlesinde RuStore); şema tanınmazsa
/// RuStore web kataloğuna düşer.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore() async {
    const pkg = 'com.soulchoice.soulchoice';
    final market = Uri.parse('market://details?id=$pkg');
    final web = Uri.parse('https://www.rustore.ru/catalog/app/$pkg');
    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {/* market şeması yoksa web'e düş */}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

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
                  child: const Icon(Icons.system_update_alt_rounded,
                      color: Colors.white, size: 64),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.update_required_title,
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
                  l10n.update_required_body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    height: 1.6,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ScButton(
                  label: l10n.update_required_btn,
                  onPressed: _openStore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
