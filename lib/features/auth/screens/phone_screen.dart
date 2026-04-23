import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';

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

  static const _commonCountries = [
    ('+7', '🇷🇺 Россия'),
    ('+90', '🇹🇷 Türkiye'),
    ('+1', '🇺🇸 USA'),
    ('+44', '🇬🇧 UK'),
    ('+49', '🇩🇪 Deutschland'),
    ('+33', '🇫🇷 France'),
    ('+971', '🇦🇪 UAE'),
  ];

  Future<void> _sendOtp() async {
    final phone = '$_countryCode${_phoneController.text.trim()}';
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Telefon numarası girin');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      if (mounted) context.go('/auth/otp', extra: phone);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
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
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Brand mark
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.phone_iphone,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                Text('Telefon\nnumaranı gir',
                    style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                Text(
                  'Sana bir doğrulama kodu göndereceğiz',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),
                // Phone input field
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.glassBgMedium,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showCountryPicker,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(_countryCode,
                                    style: AppTextStyles.bodyLarge),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more,
                                    color: AppColors.textSecondary,
                                    size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                              width: 1,
                              height: 28,
                              color: AppColors.glassBorder),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: AppTextStyles.bodyLarge,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: '999 123 45 67',
                                hintStyle: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16),
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
                const Spacer(),
                ScButton(
                  label: 'Devam et',
                  onPressed: _sendOtp,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Devam ederek Kullanım Koşulları\'nı\nkabul etmiş olursunuz',
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._commonCountries.map(
            (c) => ListTile(
              leading: Text(c.$2.split(' ')[0],
                  style: const TextStyle(fontSize: 24)),
              title: Text(c.$2.split(' ').skip(1).join(' '),
                  style: AppTextStyles.bodyLarge),
              trailing: Text(c.$1, style: AppTextStyles.mono),
              onTap: () {
                setState(() => _countryCode = c.$1);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
