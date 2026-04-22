import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/glass_card.dart';

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
    setState(() { _isLoading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      if (mounted) context.push('/auth/otp', extra: phone);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Telefon\nnumaranı gir', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Sana bir doğrulama kodu göndereceğiz',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showCountryPicker,
                        child: Row(
                          children: [
                            Text(_countryCode, style: AppTextStyles.bodyLarge),
                            const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 28, color: AppColors.glassBorder),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTextStyles.bodyLarge,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: '999 123 45 67',
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                ],
                const Spacer(),
                ScButton(
                  label: 'Devam et',
                  onPressed: _sendOtp,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Devam ederek Kullanım Koşulları\'nı kabul etmiş olursunuz',
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
      backgroundColor: const Color(0xFF111114),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ..._commonCountries.map((c) => ListTile(
                title: Text(c.$2, style: AppTextStyles.bodyLarge),
                trailing: Text(c.$1, style: AppTextStyles.mono),
                onTap: () {
                  setState(() => _countryCode = c.$1);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
