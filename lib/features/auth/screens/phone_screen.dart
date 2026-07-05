import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+7';
  bool _isLoading = false;
  String? _error;

  static const _commonCountries = [('+7', '🇷🇺 Россия')];

  Future<void> _sendOtp() async {
    setState(() => _error = null);
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.phone_error_empty);
      return;
    }
    final phone = '$_countryCode$rawPhone';
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-call-otp',
        body: {'phone': phone},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['success'] == true) {
        if (mounted) context.go('/auth/otp', extra: phone);
      } else {
        if (mounted)
          setState(
            () => _error =
                data?['error']?.toString() ??
                AppLocalizations.of(context)!.phone_error_connection,
          );
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _error = AppLocalizations.of(context)!.phone_error_connection,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: ScKeyboardFill(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // Brand mark
                  ShaderMask(
                    shaderCallback: (b) =>
                        AuroraTheme.redBlueGradient.createShader(b),
                    child: const Icon(
                      Icons.phone_iphone,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.phone_title,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      color: AuroraTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context)!.phone_subtitle,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: AuroraTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Phone input field
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AuroraTheme.glassStrong,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AuroraTheme.glassBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _countryCode,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                color: AuroraTheme.textPrimary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 28,
                              color: AuroraTheme.glassBorder,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  color: AuroraTheme.textPrimary,
                                  height: 1.6,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: '999 123 45 67',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 16,
                                    height: 1.6,
                                    color: AuroraTheme.textMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 14,
                          color: AuroraTheme.auroraRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              height: 1.5,
                              color: AuroraTheme.auroraRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  ScButton(
                    label: AppLocalizations.of(context)!.btn_continue,
                    onPressed: _sendOtp,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AuroraTheme.textSecondary,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text:
                                AppLocalizations.of(context)!.phone_terms + ' ',
                          ),
                          TextSpan(
                            text: AppLocalizations.of(
                              context,
                            )!.phone_terms_link_privacy,
                            style: const TextStyle(
                              color: AuroraTheme.auroraRed,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                Uri.parse('https://soulchoice.app/privacy'),
                              ),
                          ),
                          const TextSpan(text: ' & '),
                          TextSpan(
                            text: AppLocalizations.of(
                              context,
                            )!.phone_terms_link_terms,
                            style: const TextStyle(
                              color: AuroraTheme.auroraRed,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                Uri.parse('https://soulchoice.app/terms'),
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D12).withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: AuroraTheme.glassBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AuroraTheme.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._commonCountries.map(
                  (c) => ListTile(
                    leading: Text(
                      c.$2.split(' ')[0],
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      c.$2.split(' ').skip(1).join(' '),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: AuroraTheme.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    trailing: Text(
                      c.$1,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: AuroraTheme.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onTap: () {
                      setState(() => _countryCode = c.$1);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
