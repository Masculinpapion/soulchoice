import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
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
    if (_otp.length < 6) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phone,
        token: _otp,
        type: OtpType.sms,
      );
      if (!mounted) return;

      final user = response.user;
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
        setState(() => _error = 'Doğrulama başarısız');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/auth/phone'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.lock_open_outlined,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Kodu gir', style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium,
                    children: [
                      const TextSpan(text: 'Gönderildi: '),
                      TextSpan(
                        text: widget.phone,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      onChanged: (val) {
                        if (val.length == 1 && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (val.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        if (_otp.length == 6) _verify();
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
                // Error
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                // Resend timer
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          'Tekrar gönder ($_resendSeconds sn)',
                          style: AppTextStyles.bodyMedium,
                        )
                      : GestureDetector(
                          onTap: () async {
                            await Supabase.instance.client.auth
                                .signInWithOtp(phone: widget.phone);
                            setState(() => _resendSeconds = 60);
                            _startResendTimer();
                          },
                          child: ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.primaryGradient.createShader(b),
                            child: Text(
                              'Tekrar gönder',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                ),
                const Spacer(),
                ScButton(
                  label: 'Doğrula',
                  onPressed: _otp.length == 6 ? _verify : null,
                  isLoading: _isLoading,
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
      width: 48,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: isFocused
                  ? LinearGradient(
                      colors: [
                        AppColors.gradientStart.withOpacity(0.12),
                        AppColors.gradientEnd.withOpacity(0.08),
                      ],
                    )
                  : null,
              color: isFocused ? null : AppColors.glassBgMedium,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused
                    ? AppColors.gradientStart
                    : hasValue
                        ? AppColors.glassBorderBright
                        : AppColors.glassBorder,
                width: isFocused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLength: 1,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(fontSize: 22),
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
