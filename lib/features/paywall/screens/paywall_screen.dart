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
  String? _billingEmail;
  // Consent kanıtındaki oferta sürümü — sunucudan (feature_flags.oferta_version) okunur,
  // bayrak yoksa canlıdaki oferta tarihi
  String _ofertaVersion = '2026-07-07';

  @override
  void initState() {
    super.initState();
    _loadPaywallMode();
    _loadBillingContext();
  }

  Future<void> _loadBillingContext() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final row = await Supabase.instance.client
            .from('users')
            .select('billing_email')
            .eq('id', uid)
            .maybeSingle();
        final email = row?['billing_email'];
        if (email is String && mounted) setState(() => _billingEmail = email);
      }
      final flag = await Supabase.instance.client
          .from('feature_flags')
          .select('value')
          .eq('key', 'oferta_version')
          .maybeSingle();
      final v = (flag?['value'] as Map?)?['v'];
      if (v is String && mounted) setState(() => _ofertaVersion = v);
    } catch (_) {
      // Ön doldurma başarısızsa kullanıcı elle girer
    }
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AuroraTheme.bgDeep,
      content: Text(
        msg,
        style: const TextStyle(
            fontFamily: 'Manrope', fontSize: 13, color: Colors.white),
      ),
    ));
  }

  Future<void> _launchLink(String link) async {
    final launched = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) throw Exception('launch_failed');
  }

  // KARAR 1: tek seferlik 30 gün — mevcut F1 akışı aynen
  Future<void> _payOnce() async {
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
      await _launchLink(link);
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context)!.error_generic);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // KARAR 1 + KARAR 3: abonelik — zorunlu e-posta + consent checkbox'ı olan alt sayfa
  Future<void> _subscribe() async {
    final l10n = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController(text: _billingEmail ?? '');
    bool consent = false;
    bool sheetBusy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuroraTheme.bgDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        // viewInsets = klavye; SafeArea = sistem gezinme çubuğu. İkisi ayrı —
        // yalnız viewInsets kullanılınca buton nav bar'ın altında kalıyordu (09.07 cihaz bulgusu).
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.sub_email_label,
                  style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      letterSpacing: 1,
                      color: AuroraTheme.textMuted)),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(
                    fontFamily: 'Manrope', fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: AuroraTheme.textMuted),
                  filled: true,
                  fillColor: AuroraTheme.glassBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AuroraTheme.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AuroraTheme.glassBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setSheet(() => consent = !consent),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        consent
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: consent
                            ? AuroraTheme.auroraBlue
                            : AuroraTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.sub_consent,
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12.5,
                            height: 1.4,
                            color: AuroraTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _CtaButton(
                label: l10n.sub_continue,
                isLoading: sheetBusy,
                onTap: () async {
                  final email = emailCtrl.text.trim();
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    _snack(l10n.sub_email_invalid);
                    return;
                  }
                  if (!consent) {
                    _snack(l10n.sub_consent_required);
                    return;
                  }
                  setSheet(() => sheetBusy = true);
                  final ok = await _startSubscription(email);
                  if (ctx.mounted) {
                    if (ok) {
                      Navigator.of(ctx).pop();
                    } else {
                      setSheet(() => sheetBusy = false);
                    }
                  }
                },
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
    emailCtrl.dispose(); // modal kapandı — controller sızmasın
  }

  Future<bool> _startSubscription(String email) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-tochka-subscription',
        body: {
          'email': email,
          'source': Platform.isIOS ? 'ios_app' : 'android',
          'oferta_version': _ofertaVersion,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      final link = data?['paymentLink'] as String?;
      if (link == null) throw Exception(data?['error'] ?? 'no_link');
      await _launchLink(link);
      return true;
    } on FunctionException catch (e) {
      final code = (e.details is Map) ? (e.details as Map)['error'] : null;
      if (code == 'already_subscribed') {
        _snack(l10n.sub_already_active);
      } else if (code == 'use_resume') {
        _snack(l10n.sub_use_resume_hint);
      } else {
        _snack(l10n.error_generic);
      }
      return false;
    } catch (_) {
      if (mounted) _snack(l10n.error_generic);
      return false;
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
                      // iOS (hidden mod): satın almaya çağıran fiil yok — Seçenek B (09.07.2026)
                      _mode == 'link'
                          ? l10n.paywall_subtitle
                          : l10n.paywall_subtitle_ios,
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
                    // Seçenek B: fiyat kutusu YALNIZ satış açık moddayken —
                    // iOS'ta fiyat göstermek 3.1.1 steering riski (K öncesi şart)
                    if (_mode == 'link') ...[
                      _PriceBox(price: l10n.paywall_price),
                      const SizedBox(height: 6),
                      // KARAR 1: varsayılan abonelik + altta sade tek seferlik
                      Text(
                        l10n.sub_auto_renews,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11.5,
                          color: AuroraTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CtaButton(
                        label: l10n.sub_subscribe_cta,
                        isLoading: false,
                        onTap: _subscribe,
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _isLoading ? null : _payOnce,
                        child: _isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                l10n.sub_onetime_cta,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AuroraTheme.textSecondary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AuroraTheme.textMuted,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
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
