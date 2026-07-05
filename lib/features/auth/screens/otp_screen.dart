import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _codeLength = 4;
  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );
  bool _isLoading = false;
  String? _error;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds = (_resendSeconds - 1).clamp(0, 60));
      return _resendSeconds > 0;
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < _codeLength) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-call-otp',
        body: {'phone': widget.phone, 'code': _otp},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['access_token'] == null) {
        if (mounted)
          setState(
            () => _error =
                data?['error']?.toString() ??
                AppLocalizations.of(context)!.otp_error_failed,
          );
        return;
      }

      final refreshToken = data['refresh_token'] as String;
      final authResponse = await Supabase.instance.client.auth.setSession(
        refreshToken,
      );
      if (!mounted) return;

      final user = authResponse.user;
      if (user != null) {
        final existing = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (!mounted) return;
        if (existing != null) {
          context.go('/feed');
        } else {
          context.go('/profile/setup');
        }
      } else {
        setState(() => _error = AppLocalizations.of(context)!.otp_error_failed);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-call-otp',
        body: {'phone': widget.phone},
      );
      if (mounted) setState(() => _resendSeconds = 60);
      _startResendTimer();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AuroraTheme.textPrimary,
          ),
          onPressed: () => context.go('/auth/phone'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: ScKeyboardFill(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AuroraTheme.redBlueGradient.createShader(b),
                    child: const Icon(
                      Icons.phone_in_talk_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.otp_title,
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: AuroraTheme.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: AppLocalizations.of(context)!.otp_sent_to,
                        ),
                        TextSpan(
                          text: widget.phone,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            height: 1.5,
                            color: AuroraTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.otp_call_hint,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      height: 1.5,
                      color: AuroraTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 44),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _codeLength,
                      (i) => _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (val) {
                          if (val.length == 1 && i < _codeLength - 1) {
                            _focusNodes[i + 1].requestFocus();
                          } else if (val.isEmpty && i > 0) {
                            _focusNodes[i - 1].requestFocus();
                          }
                          if (_otp.length == _codeLength) _verify();
                        },
                        onBackspace: i > 0
                            ? () {
                                _controllers[i - 1].clear();
                                _focusNodes[i - 1].requestFocus();
                              }
                            : null,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
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
                  const SizedBox(height: 28),
                  Center(
                    child: _resendSeconds > 0
                        ? Text(
                            AppLocalizations.of(
                              context,
                            )!.otp_resend_countdown(_resendSeconds),
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: AuroraTheme.textSecondary,
                              height: 1.5,
                            ),
                          )
                        : GestureDetector(
                            onTap: _resend,
                            child: ShaderMask(
                              shaderCallback: (b) =>
                                  AuroraTheme.redBlueGradient.createShader(b),
                              child: Text(
                                AppLocalizations.of(context)!.otp_resend,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.05,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const Spacer(),
                  ScButton(
                    label: AppLocalizations.of(context)!.otp_verify,
                    onPressed: _otp.length == _codeLength ? _verify : null,
                    isLoading: _isLoading,
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
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onBackspace,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() {}));
    widget.focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.backspace &&
          widget.controller.text.isEmpty) {
        widget.onBackspace?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;
    final hasValue = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 64,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: isFocused
                  ? LinearGradient(
                      colors: [
                        AuroraTheme.auroraRed.withOpacity(0.12),
                        AuroraTheme.auroraBlue.withOpacity(0.08),
                      ],
                    )
                  : null,
              color: isFocused ? null : AuroraTheme.glassStrong,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused
                    ? AuroraTheme.auroraRed
                    : hasValue
                    ? const Color(0x40FFFFFF)
                    : AuroraTheme.glassBorder,
                width: isFocused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLength: 1,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AuroraTheme.textPrimary,
                fontSize: 24,
              ),
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
