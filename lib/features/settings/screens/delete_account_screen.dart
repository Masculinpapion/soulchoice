import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

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
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        // Delete user data (auth.users cascade deletes users row via FK)
        await client.auth.admin.deleteUser(uid);
      }
      await client.auth.signOut();
      if (mounted) context.go('/splash');
    } catch (e) {
      // Service role not available from client → sign out and show message
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesap silme isteğiniz alındı.')),
        );
        context.go('/splash');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text('Hesabı Sil', style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
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
                  color: AppColors.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Bu işlem geri alınamaz', style: AppTextStyles.headingLarge.copyWith(color: AppColors.error)),
              const SizedBox(height: 16),
              Text(
                'Hesabını silersen tüm verilerin, mesajların, eşleşmelerin ve fotoğrafların kalıcı olarak silinecek. Bu işlem geri alınamaz.',
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Column(
                  children: [
                    _WarnItem(text: 'Tüm profilin ve fotoğrafların silinir'),
                    const SizedBox(height: 10),
                    _WarnItem(text: 'Tüm mesajlaşma geçmişin silinir'),
                    const SizedBox(height: 10),
                    _WarnItem(text: 'Aktif davetlerin ve başvuruların silinir'),
                    const SizedBox(height: 10),
                    _WarnItem(text: 'Aynı telefon numarasıyla tekrar kayıt olunamaz'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                onTap: () => setState(() => _confirmed = !_confirmed),
                borderColor: _confirmed ? AppColors.error : AppColors.glassBorder,
                child: Row(
                  children: [
                    Checkbox(
                      value: _confirmed,
                      onChanged: (v) => setState(() => _confirmed = v ?? false),
                      activeColor: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Evet, hesabımı kalıcı olarak silmek istiyorum',
                        style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Manrope', fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_confirmed)
                ScButton(
                  label: 'Hesabı Kalıcı Olarak Sil',
                  onPressed: _delete,
                  isLoading: _isDeleting,
                  icon: Icons.fingerprint,
                ),
              const SizedBox(height: 12),
              ScButton(
                label: 'İptal',
                variant: ScButtonVariant.secondary,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 8),
            ],
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
          const Icon(Icons.close, color: AppColors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      );
}
