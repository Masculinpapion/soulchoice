import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

class ReportUserScreen extends StatefulWidget {
  final String userId;
  const ReportUserScreen({super.key, required this.userId});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  static const _reasons = [
    'Uygunsuz içerik / fotoğraf',
    'Taciz veya tehdit',
    'Spam veya sahte hesap',
    'Yasadışı aktivite',
    'Diğer',
  ];

  int? _selectedReason;
  final _descController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lütfen bir neden seç'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': uid,
        'reported_id': widget.userId,
        'reason': _reasons[_selectedReason!],
        'description': _descController.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Raporun alındı, inceleyeceğiz'),
          backgroundColor: AppColors.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Kullanıcıyı rapor et',
            style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Neden rapor ediyorsun?',
                style: AppTextStyles.labelLarge),
            const SizedBox(height: 12),
            ..._reasons.asMap().entries.map((e) => GestureDetector(
                  onTap: () => setState(() => _selectedReason = e.key),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedReason == e.key
                                  ? AppColors.gradientStart
                                  : AppColors.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: _selectedReason == e.key
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.gradientStart,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(e.value, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Text('Açıklama (opsiyonel)',
                style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            GlassCard(
              child: TextField(
                controller: _descController,
                style: AppTextStyles.bodyLarge,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Detay ekleyebilirsin...',
                  hintStyle: AppTextStyles.bodyMedium,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterStyle: AppTextStyles.monoSmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ScButton(
              label: _sending ? 'Gönderiliyor...' : 'Raporu gönder',
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
