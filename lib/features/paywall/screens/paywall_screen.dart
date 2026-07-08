import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Sunucu bayrağı gelene kadar platform varsayılanı: iOS'ta CTA gizli
  // (App Store External Purchase entitlement onayına kadar), Android'de açık.
  late String _mode = Platform.isIOS ? 'hidden' : 'link';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPaywallMode();
  }

  Future<void> _loadPaywallMode() async {
    try {
      final row = await Supabase.instance.client
          .from('feature_flags')
          .select('value')
          .eq('key', 'paywall_mode')
          .maybeSingle();
      final value = row?['value'];
      if (value is Map) {
        final mode = value[Platform.isIOS ? 'ios' : 'android'];
        if (mode is String && mounted) setState(() => _mode = mode);
      }
    } catch (_) {
      // Bayrak okunamazsa platform varsayılanı geçerli kalır
    }
  }

  Future<void> _pay() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-tochka-payment',
        body: {'source': Platform.isIOS ? 'ios_app' : 'android'},
      );
      final data = response.data as Map<String, dynamic>?;
      final link = data?['paymentLink'] as String?;
      if (link == null) throw Exception(data?['error'] ?? 'no_link');
      final launched = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('launch_failed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          backgroundColor: AuroraTheme.bgDeep,
          content: Text(
            AppLocalizations.of(context)!.error_generic,
            style: const TextStyle(
                fontFamily: 'Manrope', fontSize: 13, color: Colors.white),
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AuroraTheme.glassBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AuroraTheme.glassBorder),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _GradientBadge(),
                    const SizedBox(height: 26),
                    Text(
                      l10n.paywall_title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.paywall_subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        height: 1.4,
                        color: AuroraTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _PerksList(perks: [
                      l10n.paywall_perk_unlimited_invitations,
                      l10n.paywall_perk_unlimited_applications,
                      l10n.paywall_perk_chat_after_match,
                      l10n.paywall_perk_priority_moderation,
                    ]),
                    const Spacer(),
                    _PriceBox(price: l10n.paywall_price),
                    if (_mode == 'link') ...[
                      const SizedBox(height: 14),
                      _CtaButton(
                        label: l10n.paywall_cta,
                        isLoading: _isLoading,
                        onTap: _pay,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      l10n.paywall_cancel_anytime,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        color: AuroraTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
        ),
        boxShadow: [
          BoxShadow(
              color: AuroraTheme.auroraRed,
              blurRadius: 28,
              spreadRadius: -6),
        ],
      ),
      child: const Center(
        child: Icon(Icons.workspace_premium, color: Colors.white, size: 44),
      ),
    );
  }
}

class _PerksList extends StatelessWidget {
  final List<String> perks;
  const _PerksList({required this.perks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final perk in perks) ...[
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                  ),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  perk,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (perk != perks.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String price;
  const _PriceBox({required this.price});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: Center(
            child: Text(
              price,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _CtaButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
          ),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: AuroraTheme.auroraRed.withOpacity(0.55),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
      ),
    );
  }
}
